import PlatformCLib
import CFileSystem
import SystemPackage

#if canImport(WinSDK)
import BasicContainers
#endif 



package struct DirectoryEntryRecursiveEnumerator: ~Copyable {

    package enum Element {
        case entry(DirectoryEntry)
        case leavingDir(FilePath, SystemError?)
        case entryError(FilePath, SystemError)
        case subTreeError(FilePath, SystemError)

        package var path: FilePath {
            switch self {
                case .entry(let entry):          entry.path
                case .leavingDir(let path, _):   path
                case .entryError(let path, _):   path
                case .subTreeError(let path, _): path
            }
        }
    }

    #if canImport(WinSDK)

    package typealias SystemEntryDataType = WIN32_FIND_DATAW
    private var findHandleStack: UniqueArray<InternalFS.WindowsFindHandle> = .init()
    private var relativePathStack: FilePath = .init("")

    #else

    package typealias SystemEntryDataType = FTSENT
    // private var entryStream: UnsafeMutablePointer<FTS>
    private var ftsStream: InternalFS.PosixFTSStream?
    private var prevLevel: Int16 = 0

    #endif

    package let rootPath: FilePath
    package let doStat: Bool
    package let options: FileOperationOptions.DirectoryTraversalOption

    package private(set) var ended: Bool = false


    package init(path: FilePath, doStat: Bool = true, options: FileOperationOptions.DirectoryTraversalOption = []) {
        self.rootPath = path
        self.doStat = doStat
        self.options = options
    }


    deinit {
        #if canImport(WinSDK)
        var findHandleStack = findHandleStack
        while let handle = findHandleStack.popLast() {
            try? handle.close()
        }
        #else 
        try? ftsStream?.close()
        #endif 
    }


    package mutating func next() throws(SystemError) -> Element? {

        guard !ended else { return nil }
    
        do {
            if let entry = try _next() {
                return entry
            } else {
                try endIter()
                return nil
            }
        } catch {
            try? endIter()
            throw error
        }

    }


    private mutating func _next() throws(SystemError) -> Element? {

        guard !ended else { return nil }
    
        #if canImport(WinSDK)

        while true {

            SetLastError(DWORD(NO_ERROR))

            var findData = WIN32_FIND_DATAW()

            if findHandleStack.count == relativePathStack.components.count + 1 {

                // On Windows, `findHandleStack` maintains a stack of dir handles corresponding to the current opened directories.
                // Besides the root dir, each opened subdir has its name stored in `relativePathStack`, while the root dir is represented 
                // by the `rootPath`. So ideally, the num of opened dir handles should be 1 larger than the num of file names in `relativePathStack`.
                // In this case, the top handle in `findHandleStack` is the current dir we are traversing. 

                // temporarily pop the handle on stack top for reading the next entry
                guard var findHandle = findHandleStack.popLast() else { return nil }

                do {
                    if let data = try findHandle.next() {
                        findData = data
                        findHandleStack.append(findHandle)      // Push it back
                    } else {
                        if findHandleStack.isEmpty { return nil }
                        // Return back to the parent directory (findHandle will be closed automatically in deinit)
                        let leavingDirPath = FilePath(root: nil, relativePathStack.components)
                        relativePathStack.removeLastComponent()
                        if options.contains(.skipDir) {
                            continue
                        } else {
                            return .leavingDir(leavingDirPath, nil)
                        }
                    }
                } catch {
                    // if any error occurs, we need to stop traversing this dir and return back to the parent dir
                    // since this is an early return due to error, we also need to include the error in the `leavingDir` element
                    let leavingDirPath = FilePath(root: nil, relativePathStack.components)
                    relativePathStack.removeLastComponent()
                    return .leavingDir(leavingDirPath, error)
                }

            } else {

                // However, if the num of opened dir handles is equal to the num of file names in `relativePathStack`, the iterator is trying to 
                // enter a new subdir, whose file name is the top file name in `relativePathStack`, but the corresponding dir handle has not been 
                // opened yet. In this case, we open a new dir handle for this subdir and push it onto `findHandleStack`.

                let pathToOpen = rootPath.appending(relativePathStack.components)
                var handle = InternalFS.WindowsFindHandle(path: pathToOpen)
                do {
                    findData = try handle.next()!
                } catch {
                    // fail to enter the subdir
                    // handle closing will be done automatically in deinit (since we don't care the error when closing handle)
                    if relativePathStack.isEmpty {
                        // the current dir is the root dir, in this case we just stop and fail the entire enumeration
                        // (This is slightly different from POSIX, which will throw the error in the initializer)
                        throw error
                    }
                    relativePathStack.removeLastComponent()
                    return .subTreeError(pathToOpen, error)
                }

                findHandleStack.append(handle)

            }

            let type = extractEntryType(of: findData)

            let path = extractPath(from: findData)
            let name = path.lastComponent!

            if type == .directory && (name.kind == .regular) {
                // Entering a subdirectory. 
                // Push only the name of the subdir onto the `relativePathStack`, then in the next iteration, the corresponding dir 
                // handle will be opened 
                relativePathStack.append(name)
            }

            if options.contains(.skipDir) && type == .directory { 
                continue 
            } else if !options.contains(.includeDotEntries) && name.kind != .regular {
                continue
            } else {
                return DirectoryEntry(path: path, type: type).map { .entry($0) }
            }

        }

        #else

        if ftsStream == nil {
            ftsStream = try .init(path: rootPath, doStat: doStat, includeDots: options.contains(.includeDotEntries))
        }

        while let entry = try ftsStream?.next() {

            if entry.fts_level == FTS_ROOTLEVEL { continue }

            defer { prevLevel = entry.fts_level }

            if options.contains(.skipDir) {
                switch Int32(entry.fts_info) {
                    case FTS_D, FTS_DP, FTS_DOT: continue
                    default:                     break
                }
            }

            // on Posix, no need to check the dot entries since it's already done by the FTS library itself

            lazy var path = extractPath(from: entry)

            switch Int32(entry.fts_info) {
                case FTS_NS:
                    return .entryError(path, .init(code: entry.fts_errno)!)
                case FTS_ERR where entry.fts_level > prevLevel:
                    return .leavingDir(path, .init(code: entry.fts_errno)!)
                case FTS_ERR:
                    return .entryError(path, .init(code: entry.fts_errno)!)
                case FTS_DNR: 
                    return .subTreeError(path, .init(code: entry.fts_errno)!)
                case FTS_DP:
                    return .leavingDir(path, nil)
                case FTS_DC:
                    continue
                default:
                    break
            }

            let type = extractEntryType(from: entry)

            return DirectoryEntry(path: path, type: type).map { .entry($0) }

        }

        return nil

        #endif

    }


    private func extractPath(from systemEntry: borrowing SystemEntryDataType) -> FilePath {
        #if canImport(WinSDK)
            let name = withUnsafePointer(to: systemEntry.cFileName) { ptr in 
                ptr.withMemoryRebound(to: WCHAR.self, capacity: Int(MAX_PATH)) { wcharPtr in
                    FilePath.Component(platformString: wcharPtr)!
                }
            }
            return FilePath(root: nil, relativePathStack.components + CollectionOfOne(name))
        #else
            var path = FilePath(platformString: systemEntry.fts_path)
            _ = path.removePrefix(rootPath)
            return path
        #endif 
    }


    #if canImport(WinSDK)

    private func extractEntryType(of systemEntry: borrowing SystemEntryDataType) -> FileType {
        let fileAttributes = systemEntry.dwFileAttributes
        let hasReparseTagSymlink = (systemEntry.dwReserved0 == IO_REPARSE_TAG_SYMLINK)

        return if fileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
            hasReparseTagSymlink ? .symlink : .unknown
        } else if fileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0 {
            .directory
        } else {
            .regular
        }
    }

    #else

    private func extractEntryType(from systemEntry: borrowing SystemEntryDataType) -> FileType {
        return switch Int32(systemEntry.fts_info) {
            case FTS_F:         .regular
            case FTS_D:         .directory
            case FTS_DOT:       .directory
            case FTS_SL:        .symlink
            case FTS_SLNONE:    .symlink
            case FTS_DEFAULT:   .init(mode: systemEntry.fts_statp.pointee.st_mode)
            case FTS_NSOK:      .unknown
            default:            .unknown
        }
    }
    
    #endif 


    private mutating func _clean() throws(SystemError) {

        guard !ended else { return }

        #if canImport(WinSDK)
        
        defer {
            // if any error occurs during closing the dir handles, we still need to continue closing the remaining ones,
            // and in this case, we ignore any further errors
            while let handle = findHandleStack.popLast() {
                try? handle.close()
            }    
        }
        while let handle = findHandleStack.popLast() {
            try handle.close()
        }
        // try SystemError.check()

        #else

        try ftsStream.take()?.close()

        #endif

    }


    private mutating func endIter() throws(SystemError) {
        #if canImport(WinSDK)
        defer {
            findHandleStack.removeAll()
        }
        #endif
        defer {
            ended = true
        }
        try _clean()
    }

}