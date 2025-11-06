import SystemPackage

import PlatformCLib
import CFileSystem



extension DirectoryEntryIterator {

    public struct DirectoryEntryRecursiveIterator: DirectoryEntryIteratorProtocol, ~Copyable {

        #if canImport(WinSDK)

        typealias SystemEntryDataType = WIN32_FIND_DATAW
        private var findHandleStack: [WinSDK.HANDLE] = []
        private var relativePathStack: FilePath = .init("")

        #else

        typealias SystemEntryDataType = UnsafeMutablePointer<FTSENT>
        private var entryStream: UnsafeMutablePointer<FTS>

        #endif

        public let rootPath: FilePath

        public private(set) var ended: Bool = false


        public init(path: FilePath) throws(FileError) {

            #if canImport(WinSDK)

            // The find handle will not be initialized here, and will only be initialized on the first call to next()
            // This is because on Windows, we need to use FindFirstFileExW to open the handle, which will give us the first result directly.

            #else

            let entryStream = path.string.withCString { cStr in 
                fts_open([UnsafeMutablePointer<CChar>(mutating: cStr), nil], FTS_PHYSICAL | FTS_NOCHDIR | FTS_SEEDOT, nil)
            }
            guard let entryStream else {
                try FileError.assertError(operationDescription: .openingDirStream(forDirectoryAt: path))
            }

            self.entryStream = entryStream

            #endif

            self.rootPath = path

        }


        deinit {
            try? _clean()
        }


        public mutating func next() -> Result<DirectoryEntry, FileError>? {

            guard !ended else { return nil }
        
            do {
                if let entry = try _nextThrowing() {
                    return .success(entry)
                } else {
                    try endIter()
                    return nil
                }
            } catch {
                try? endIter()
                return .failure(error)
            }

        }


        private mutating func _nextThrowing() throws(FileError) -> DirectoryEntry? {

            guard !ended else { return nil }
        
            #if canImport(WinSDK)

            SetLastError(DWORD(NO_ERROR))

            var findData = WIN32_FIND_DATAW()

            if findHandleStack.count == relativePathStack.components.count + 1 {

                // On Windows, `findHandleStack` maintains a stack of dir handles corresponding to the current opened directories.
                // Besides the root dir, each opened subdir has its name stored in `relativePathStack`, while the root dir is represented 
                // by the `rootPath`. So ideally, the num of opened dir handles should be 1 larger than the num of file names in `relativePathStack`.
                // In this case, the top handle in `findHandleStack` is the current dir we are traversing. 

                while let findHandle = findHandleStack.last {

                    if FindNextFileW(findHandle, &findData) { break }

                    let errorCode = GetLastError()

                    if errorCode == ERROR_NO_MORE_FILES {
                        // Return back to the parent directory
                        findHandleStack.removeLast()
                        relativePathStack.removeLastComponent()
                        FindClose(findHandle)
                    } else {
                        throw .init(code: .init(rawValue: errorCode), operationDescription: .readingDirEntries(at: rootPath))
                    }

                }

                if findHandleStack.isEmpty { return nil }

            } else {

                // However, if the num of opened dir handles is equal to the num of file names in `relativePathStack`, the iterator is trying to 
                // enter a new subdir, whose file name is the top file name in `relativePathStack`, but the corresponding dir handle has not been 
                // opened yet. In this case, we open a new dir handle for this subdir and push it onto `findHandleStack`.

                let pathToOpen = rootPath.appending(relativePathStack.components).appending("*")

                let newFindHandle = pathToOpen.string.withCString(encodedAs: UTF16.self) { cStr in
                    FindFirstFileExW(cStr, FindExInfoBasic, &findData, FindExSearchNameMatch, nil, DWORD(FIND_FIRST_EX_LARGE_FETCH))
                }

                guard let newFindHandle, newFindHandle != INVALID_HANDLE_VALUE else {
                    try FileError.assertError(operationDescription: .readingDirEntries(at: rootPath))
                }

                findHandleStack.append(newFindHandle)

            }

            let entry = extractEntryInfo(from: findData)

            if let entry, entry.type == .directory && (entry.name != "." && entry.name != "..") {
                // Entering a subdirectory. 
                // Push only the name of the subdir onto the `relativePathStack`, then in the next iteration, the corresponding dir 
                // handle will be opened 
                relativePathStack.append(entry.name)
            }

            return entry

            #else

            errno = 0

            while let entry = fts_read(entryStream) {

                if entry.pointee.fts_level == FTS_ROOTLEVEL { continue }

                switch Int32(entry.pointee.fts_info) {
                    case FTS_ERR: 
                        throw .init(code: .init(rawValue: entry.pointee.fts_errno), operationDescription: .readingDirEntries(at: rootPath))
                    default: break
                }

                switch Int32(entry.pointee.fts_info) {
                    case FTS_NS:        continue
                    case FTS_NSOK:      continue
                    case FTS_DNR:       continue
                    case FTS_DP:        continue   
                    case FTS_DC:        continue
                    default:            break
                }

                return extractEntryInfo(from: entry)

            }

            try FileError.check(operationDescription: .readingDirEntries(at: rootPath))

            return nil

            #endif

        }


        private func extractEntryInfo(from systemEntry: borrowing SystemEntryDataType) -> DirectoryEntry? {

            #if canImport(WinSDK)

                let fileAttributes = systemEntry.dwFileAttributes

                let name = withUnsafePointer(to: systemEntry.cFileName) { ptr in 
                    ptr.withMemoryRebound(to: WCHAR.self, capacity: Int(MAX_PATH)) { wcharPtr in
                        String(decodingCString: wcharPtr, as: UTF16.self)
                    }
                }

                let hasReparseTagSymlink = (systemEntry.dwReserved0 == IO_REPARSE_TAG_SYMLINK)

                let type = if fileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0 {
                    .directory
                } else if fileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 && hasReparseTagSymlink {
                    .symlink
                } else if fileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
                    .unknown
                } else {
                    .regular
                } as FileInfo.FileType

                return .init(path: rootPath.appending(relativePathStack.components).appending(name), type: type)

            #else

                let entryPath = FilePath(String(cString: systemEntry.pointee.fts_path))

                let fileType = switch Int32(systemEntry.pointee.fts_info) {
                    case FTS_F:         .regular
                    case FTS_D:         .directory
                    case FTS_DOT:       .directory
                    case FTS_DEFAULT:   .init(mode: systemEntry.pointee.fts_statp.pointee.st_mode)
                    case FTS_SL:        .symlink
                    case FTS_SLNONE:    .symlink
                    default:            .unknown
                } as FileInfo.FileType

                return .init(path: entryPath, type: fileType)

            #endif 

        }


        private func _clean() throws(FileError) {

            guard !ended else { return }

            #if canImport(WinSDK)
            
            SetLastError(DWORD(NO_ERROR))
            for handle in findHandleStack {
                FindClose(handle)
            }
            try FileError.check(operationDescription: .readingDirEntries(at: rootPath))

            #else

            try execThrowingCFunction(operationDescription: .readingDirEntries(at: rootPath)) {
                fts_close(entryStream)
            }

            #endif

        }


        private mutating func endIter() throws(FileError) {
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

}