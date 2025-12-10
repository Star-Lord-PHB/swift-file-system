import PlatformCLib
import CFileSystem
import SystemPackage



struct DirectoryEntryRecursiveEnumerator: ~Copyable {

    enum Element {
        case entry(DirectoryEntry)
        case leavingDir(FilePath)
        case entryError(FilePath, SystemError)

        var path: FilePath {
            switch self {
                case .entry(let entry):         entry.path
                case .entryError(let path, _):  path
                case .leavingDir(let path):     path
            }
        }
    }

    #if canImport(WinSDK)

    typealias SystemEntryDataType = WIN32_FIND_DATAW
    private var findHandleStack: [WinSDK.HANDLE] = []
    private var relativePathStack: FilePath = .init("")

    #else

    typealias SystemEntryDataType = UnsafeMutablePointer<FTSENT>
    private var entryStream: UnsafeMutablePointer<FTS>

    #endif

    let rootPath: FilePath
    let doStat: Bool

    private(set) var ended: Bool = false


    init(path: FilePath, doStat: Bool = true) throws(SystemError) {

        #if canImport(WinSDK)

        // The find handle will not be initialized here, and will only be initialized on the first call to next()
        // This is because on Windows, we need to use FindFirstFileExW to open the handle, which will give us the first result directly.

        #else

        var ftsFlags = FTS_PHYSICAL | FTS_NOCHDIR | FTS_SEEDOT | FTS_COMFOLLOW
        if doStat == false {
            ftsFlags |= FTS_NOSTAT
        }

        let entryStream = path.withPlatformString { cStr in
            fts_open([UnsafeMutablePointer<CChar>(mutating: cStr), nil], ftsFlags, nil)
        }
        guard let entryStream else {
            try SystemError.assertError()
        }

        self.entryStream = entryStream

        #endif

        self.rootPath = path
        self.doStat = doStat

    }


    deinit {
        try? _clean()
    }


    mutating func next() throws(SystemError) -> Element? {

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

        // TODO: Migrate to use .entryError on Windows

        SetLastError(DWORD(NO_ERROR))

        var findData = WIN32_FIND_DATAW()

        if findHandleStack.count == relativePathStack.components.count + 1 {

            // On Windows, `findHandleStack` maintains a stack of dir handles corresponding to the current opened directories.
            // Besides the root dir, each opened subdir has its name stored in `relativePathStack`, while the root dir is represented 
            // by the `rootPath`. So ideally, the num of opened dir handles should be 1 larger than the num of file names in `relativePathStack`.
            // In this case, the top handle in `findHandleStack` is the current dir we are traversing. 

            guard let findHandle = findHandleStack.last else { return nil }

            if FindNextFileW(findHandle, &findData) == false {

                let errorCode = GetLastError()

                if errorCode == ERROR_NO_MORE_FILES {
                    // Return back to the parent directory
                    let leavingDirPath = FilePath(root: nil, relativePathStack.components)
                    findHandleStack.removeLast()
                    relativePathStack.removeLastComponent()
                    FindClose(findHandle)
                    return .leavingDir(leavingDirPath)
                } else {
                    throw .init(code: errorCode)
                }

            }

        } else {

            // However, if the num of opened dir handles is equal to the num of file names in `relativePathStack`, the iterator is trying to 
            // enter a new subdir, whose file name is the top file name in `relativePathStack`, but the corresponding dir handle has not been 
            // opened yet. In this case, we open a new dir handle for this subdir and push it onto `findHandleStack`.

            let pathToOpen = rootPath.appending(relativePathStack.components).appending("*")

            let newFindHandle = pathToOpen.string.withCString(encodedAs: UTF16.self) { cStr in
                FindFirstFileExW(cStr, FindExInfoBasic, &findData, FindExSearchNameMatch, nil, DWORD(FIND_FIRST_EX_LARGE_FETCH))
            }

            guard let newFindHandle, newFindHandle != INVALID_HANDLE_VALUE else {
                try SystemError.assertError()
            }

            findHandleStack.append(newFindHandle)

        }

        let path = extractPath(from: findData)
        let name = path.lastComponent!.string
        let type = extractEntryType(of: findData)

        if type == .directory && (name != "." && name != "..") {
            // Entering a subdirectory. 
            // Push only the name of the subdir onto the `relativePathStack`, then in the next iteration, the corresponding dir 
            // handle will be opened 
            relativePathStack.append(name)
        }

        return DirectoryEntry(path: path, type: type).map { .entry($0) }

        #else

        errno = 0

        while let entry = fts_read(entryStream) {

            if entry.pointee.fts_level == FTS_ROOTLEVEL { continue }

            lazy var path = extractPath(from: entry)

            switch Int32(entry.pointee.fts_info) {
                case FTS_ERR, FTS_NS, FTS_DNR:
                    return .entryError(path, .init(code: entry.pointee.fts_errno))
                case FTS_DP:
                    return .leavingDir(path)
                case FTS_DC:
                    continue
                default:
                    break
            }

            let type = extractEntryType(from: entry, hasStat: entry.pointee.fts_info == FTS_NSOK)

            return DirectoryEntry(path: path, type: type).map { .entry($0) }

        }

        try SystemError.check()

        return nil

        #endif

    }


    private func extractPath(from systemEntry: borrowing SystemEntryDataType) -> FilePath {
        #if canImport(WinSDK)
            let name = withUnsafePointer(to: systemEntry.cFileName) { ptr in 
                ptr.withMemoryRebound(to: WCHAR.self, capacity: Int(MAX_PATH)) { wcharPtr in
                    String(decodingCString: wcharPtr, as: UTF16.self)
                }
            }
            return FilePath(root: nil, relativePathStack.components + CollectionOfOne(name))
        #else
            var path = FilePath(platformString: systemEntry.pointee.fts_path)
            _ = path.removePrefix(rootPath)
            return path
        #endif 
    }


    #if canImport(WinSDK)

    private func extractEntryType(of systemEntry: borrowing SystemEntryDataType) -> FileInfo.FileType {
        let fileAttributes = systemEntry.dwFileAttributes
        let hasReparseTagSymlink = (systemEntry.dwReserved0 == IO_REPARSE_TAG_SYMLINK)

        return if fileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0 {
            .directory
        } else if fileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 && hasReparseTagSymlink {
            .symlink
        } else if fileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
            .unknown
        } else {
            .regular
        }
    }

    #else

    private func extractEntryType(from systemEntry: borrowing SystemEntryDataType, hasStat: Bool) -> FileInfo.FileType {
        return switch Int32(systemEntry.pointee.fts_info) {
            case FTS_F:         .regular
            case FTS_D:         .directory
            case FTS_DOT:       .directory
            case FTS_SL:        .symlink
            case FTS_SLNONE:    .symlink
            case FTS_DEFAULT:   hasStat ? .init(mode: systemEntry.pointee.fts_statp.pointee.st_mode) : .unknown
            default:            .unknown
        }
    }
    
    #endif 


    private func _clean() throws(SystemError) {

        guard !ended else { return }

        #if canImport(WinSDK)
        
        SetLastError(DWORD(NO_ERROR))
        for handle in findHandleStack {
            FindClose(handle)
        }
        try SystemError.check()

        #else

        try execThrowingCFunction() {
            fts_close(entryStream)
        }

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