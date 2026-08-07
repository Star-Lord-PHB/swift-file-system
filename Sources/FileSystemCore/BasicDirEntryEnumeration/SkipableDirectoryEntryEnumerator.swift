import PlatformCLib
import CFileSystem
import struct SystemPackage.FilePath

import BasicContainers



package struct SkipableDirectoryEntryEnumerator: ~Copyable {

    package enum Element {
        case entry(DirectoryEntry)
        case leavingDir(FilePath, LowLevelError?)
        case entryError(FilePath, LowLevelError)
        case subTreeError(FilePath, LowLevelError)

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

    package typealias SystemEntryDataType = dirent
    private var entryStreamStack: UniqueArray<InternalFS.PosixDirectoryStream> = .init()
    private var relativePathStack: FilePath = .init("")

    #endif

    package let rootPath: FilePath
    package let options: FileOperationOptions.DirectoryTraversalOption

    package private(set) var ended: Bool = false

    package var currentDirPathComponents: FilePath.ComponentView {
        return relativePathStack.components
    }


    package init(path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) {
        self.rootPath = path
        self.options = options
    }


    deinit {
        #if canImport(WinSDK)
        var findHandleStack = findHandleStack
        while let handle = findHandleStack.popLast() {
            try? handle.close()
        }
        #else 
        var entryStreamStack = entryStreamStack
        while let stream = entryStreamStack.popLast() {
            try? stream.close()
        }
        #endif 
    }


    package mutating func next(skipCurrentDir: Bool = false) throws(LowLevelError) -> Element? {

        guard !ended else { return nil }
    
        do {
            if let entry = try _next(skipCurrentDir: skipCurrentDir) {
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


    private mutating func _next(skipCurrentDir: Bool = false) throws(LowLevelError) -> Element? {

        guard !ended else { return nil }

        var skipCurrentDir = skipCurrentDir
    
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

                if skipCurrentDir {
                    // Skipping a dir that is already being read means leaving it early, so a `leavingDir` element
                    // is still emitted. (Skipping before the dir is entered at all is a different request and
                    // deliberately emits nothing; see the other branch below.)
                    // Skipping the root ends the whole enumeration: it is never emitted as an entry and its
                    // relative path is empty, so it cannot be named by a `leavingDir` element either.
                    if relativePathStack.isEmpty { return nil }
                    let leavingDirPath = FilePath(root: nil, relativePathStack.components)
                    relativePathStack.removeLastComponent()
                    if options.contains(.skipDir) {
                        skipCurrentDir = false
                        continue
                    } else {
                        return .leavingDir(leavingDirPath, nil)
                    }
                }

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
                    if relativePathStack.isEmpty {
                        // The root dir is never emitted as an entry and its relative path is empty, so it cannot be
                        // named by a `leavingDir` element; failing to read it fails the whole enumeration instead
                        // (aligned with POSIX, where a root-level FTS error is thrown).
                        throw error
                    }
                    let leavingDirPath = FilePath(root: nil, relativePathStack.components)
                    relativePathStack.removeLastComponent()
                    return .leavingDir(leavingDirPath, error)
                }

            } else {

                // However, if the num of opened dir handles is equal to the num of file names in `relativePathStack`, the iterator is trying to 
                // enter a new subdir, whose file name is the top file name in `relativePathStack`, but the corresponding dir handle has not been 
                // opened yet. In this case, we open a new dir handle for this subdir and push it onto `findHandleStack`.

                if skipCurrentDir {
                    // Skipping a dir before its contents have been accessed at all means "do not enter it", so
                    // no `leavingDir` element is emitted for it (unlike the early-leave case in the branch above).
                    if relativePathStack.isEmpty { return nil }
                    relativePathStack.removeLastComponent()
                    skipCurrentDir = false
                    continue
                }

                let pathToOpen = rootPath.appending(relativePathStack.components)
                var handle = InternalFS.WindowsFindHandle(path: pathToOpen)
                do {
                    findData = try handle.next()!   // this force unwrap is safe since a dir always has at least "." and ".." entries
                } catch {
                    // fail to enter the subdir
                    // handle closing will be done automatically in deinit (since we don't care the error when closing handle)
                    if relativePathStack.isEmpty {
                        // the current dir is the root dir, in this case we just stop and fail the entire enumeration
                        // (This is slightly different from POSIX, which will throw the error in the initializer)
                        throw error
                    }
                    let failedDirPath = FilePath(root: nil, relativePathStack.components)
                    relativePathStack.removeLastComponent()
                    return .subTreeError(failedDirPath, error)
                }

                findHandleStack.append(handle)

            }

            let path = extractPath(from: findData)
            let name = path.lastComponent!

            if !options.contains(.includeDotEntries) && name.kind != .regular {
                // '.' and '..' are dropped anyway (kept symmetric with the POSIX branch, where returning
                // early also avoids resolving their type)
                continue
            }

            let type = extractEntryType(of: findData)

            if type == .directory && (name.kind == .regular) {
                // Entering a subdirectory.
                // Push only the name of the subdir onto the `relativePathStack`, then in the next iteration, the corresponding dir
                // handle will be opened
                relativePathStack.append(name)
            }

            if options.contains(.skipDir) && type == .directory {
                continue
            } else {
                return DirectoryEntry(path: path, type: type).map { .entry($0) }
            }

        }

        #else

        while true {

            errno = 0

            var dirent = dirent()

            if entryStreamStack.count == relativePathStack.components.count + 1 {

                guard var entryStream = entryStreamStack.popLast() else { return nil }

                if skipCurrentDir {
                    // Skipping a dir that is already being read means leaving it early, so a `leavingDir` element
                    // is still emitted. (Skipping before the dir is entered at all is a different request and
                    // deliberately emits nothing; see the other branch below.)
                    // Skipping the root ends the whole enumeration: it is never emitted as an entry and its
                    // relative path is empty, so it cannot be named by a `leavingDir` element either.
                    if relativePathStack.isEmpty { return nil }
                    let leavingDirPath = FilePath(root: nil, relativePathStack.components)
                    relativePathStack.removeLastComponent()
                    if options.contains(.skipDir) {
                        skipCurrentDir = false
                        continue
                    } else {
                        return .leavingDir(leavingDirPath, nil)
                    }
                }

                do {
                    if let entry = try entryStream.next() {
                        dirent = entry
                        entryStreamStack.append(entryStream)    // Push it back
                    } else {
                        if entryStreamStack.isEmpty { return nil }
                        // Return back to the parent directory (stream closing will be done automatically in deinit)
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
                    if relativePathStack.isEmpty {
                        // The root dir is never emitted as an entry and its relative path is empty, so it cannot be
                        // named by a `leavingDir` element; failing to read it fails the whole enumeration instead
                        // (aligned with POSIX, where a root-level FTS error is thrown).
                        throw error
                    }
                    let leavingDirPath = FilePath(root: nil, relativePathStack.components)
                    relativePathStack.removeLastComponent()
                    return .leavingDir(leavingDirPath, error)
                }

            } else {

                // Entering a new subdir

                if skipCurrentDir {
                    // Skipping a dir before its contents have been accessed at all means "do not enter it", so
                    // no `leavingDir` element is emitted for it (unlike the early-leave case in the branch above).
                    if relativePathStack.isEmpty { return nil }
                    relativePathStack.removeLastComponent()
                    skipCurrentDir = false
                    continue
                }

                let pathToOpen = rootPath.appending(relativePathStack.components)
                // var stream = try InternalFS.PosixDirectoryStream(unsafeSystemHandle: .openDir(at: pathToOpen))
                do {
                    var stream = try InternalFS.PosixDirectoryStream(unsafeSystemHandle: .openDir(at: pathToOpen))
                    dirent = try stream.next()!     // this force unwrap is safe since a dir always has at least "." and ".." entries
                    entryStreamStack.append(stream)
                } catch {
                    // fail to enter the subdir
                    // stream closing will be done automatically in deinit (since we don't care the error when closing stream)
                    if relativePathStack.isEmpty {
                        // the current dir is the root dir, in this case we just stop and fail the entire enumeration
                        throw error
                    }
                    let failedDirPath = FilePath(root: nil, relativePathStack.components)
                    relativePathStack.removeLastComponent()
                    return .subTreeError(failedDirPath, error)
                }

            }

            let path = extractPath(from: dirent)
            let name = path.lastComponent!

            if !options.contains(.includeDotEntries) && name.kind != .regular {
                // '.' and '..' are dropped anyway; returning early also avoids resolving their type below
                continue
            }

            var type = extractEntryType(from: dirent)

            if type == .unknown {
                // `d_type` is optional in POSIX: some file systems always report `DT_UNKNOWN`.
                // Fall back to an explicit no-follow stat of the entry itself, otherwise subdirectories
                // would never be recognized and therefore never entered.
                do {
                    type = try InternalFS.type(ofItemAt: rootPath.appending(path.components))
                } catch {
                    // a single unresolvable entry must not fail the whole enumeration
                    return .entryError(path, error)
                }
            }

            if type == .directory && (name.kind == .regular) {
                // Entering a subdirectory.
                // Push only the name of the subdir onto the `relativePathStack`, then in the next iteration, the corresponding dir
                // stream will be opened
                relativePathStack.append(name)
            }
            if options.contains(.skipDir) && type == .directory {
                continue
            } else {
                return DirectoryEntry(path: path, type: type).map { .entry($0) }
            }

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
        let nameLen = withUnsafeBytes(of: systemEntry.d_name) { $0.count }
        let name = withUnsafePointer(to: systemEntry.d_name) { originalPtr in 
            originalPtr.withMemoryRebound(to: CChar.self, capacity: nameLen) { pointer in
                FilePath.Component(platformString: pointer)!
            }
        }
        return FilePath(root: nil, relativePathStack.components + CollectionOfOne(name))
        #endif 
    }


    #if canImport(WinSDK)

    private func extractEntryType(of systemEntry: borrowing SystemEntryDataType) -> FileKind {
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

    private func extractEntryType(from systemEntry: borrowing SystemEntryDataType) -> FileKind {
        return switch systemEntry.d_type {
            case .init(DT_REG):     .regular
            case .init(DT_DIR):     .directory
            case .init(DT_LNK):     .symlink
            case .init(DT_SOCK):    .socket
            case .init(DT_BLK):     .block
            case .init(DT_CHR):     .character
            case .init(DT_FIFO):    .fifo
            case .init(DT_UNKNOWN): .unknown
            default:                .unknown
        }
    }
    
    #endif 


    private mutating func _clean() throws(LowLevelError) {

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

        #else

        defer {
            // if any error occurs during closing the dir streams, we still need to continue closing the remaining ones,
            // and in this case, we ignore any further errors
            while let stream = entryStreamStack.popLast() {
                try? stream.close()
            }
        }
        while let stream = entryStreamStack.popLast() {
            try stream.close()
        }

        #endif

    }


    private mutating func endIter() throws(LowLevelError) {
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
