import SystemPackage

import Foundation
import CFileSystem



extension DirectoryEntryIterator {

    public struct DirectoryEntryDirectIterator: DirectoryEntryIteratorProtocol, ~Escapable, ~Copyable {

        #if canImport(WinSDK)
        typealias SystemEntryDataType = WIN32_FIND_DATAW
        private var findHandle: WinSDK.HANDLE?
        #else
        typealias SystemEntryDataType = UnsafeMutablePointer<dirent>
        private var dirStream: OpaquePointer
        #endif

        public let rootPath: FilePath

        public private(set) var ended: Bool = false


        @_lifetime(immortal)
        init(unsafeUnownedSystemHandle handle: UnsafeUnownedSystemHandle, path: FilePath) throws(FileError) {
            try self.init(unsafeRawHandle: handle.unsafeRawHandle, path: path)
        }


        @_lifetime(immortal)
        private init(unsafeRawHandle: UnsafeSystemHandle.SystemHandleType, path: FilePath) throws(FileError) {

            #if canImport(WinSDK)

            // The find handle will not be initialized here, and will only be initialized on the first call to next()
            // This is because on Windows, we need to use FindFirstFileExW to open the handle, which will give us the first result directly.
            self.findHandle = nil

            #else

            let duplicatedFd = dup(unsafeRawHandle)
            guard duplicatedFd >= 0 else {
                try FileError.assertError(operationDescription: .openingDirStream(forDirectoryAt: path))
            }

            guard let dirStream = fdopendir(duplicatedFd) else {
                try FileError.assertError(operationDescription: .openingDirStream(forDirectoryAt: path))
            }

            self.dirStream = .init(UnsafeRawPointer(dirStream))

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


        mutating func _nextThrowing() throws(FileError) -> DirectoryEntry? {

            #if canImport(WinSDK)

            var findData = WIN32_FIND_DATAW()

            if let findHandle {

                guard FindNextFileW(findHandle, &findData) else {
                    let errorCode = GetLastError()
                    if errorCode == ERROR_NO_MORE_FILES {
                        return nil
                    } else {
                        throw .init(code: .init(rawValue: errorCode), operationDescription: .readingDirEntries(at: rootPath))
                    }
                }

            } else {

                findHandle = rootPath.appending("*").string.withCString(encodedAs: UTF16.self) { cStr in 
                    FindFirstFileExW(cStr, FindExInfoBasic, &findData, FindExSearchNameMatch, nil, DWORD(FIND_FIRST_EX_LARGE_FETCH))
                }
                guard let findHandle, findHandle != INVALID_HANDLE_VALUE else {
                    try FileError.assertError(operationDescription: .readingDirEntries(at: rootPath))
                }

            }

            return extractEntryInfo(from: findData)

            #else

            errno = 0

            guard let dirEntryPtr = readdir(.init(dirStream)) else {
                try FileError.check(operationDescription: .readingDirEntries(at: rootPath))
                return nil
            }

            return extractEntryInfo(from: dirEntryPtr)

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

                return .init(path: rootPath.appending(name), type: type)

            #else

                let nameLen = withUnsafeBytes(of: &systemEntry.pointee.d_name) { $0.count }

                let name = systemEntry.pointer(to: \.d_name)!.withMemoryRebound(to: CChar.self, capacity: nameLen) { pointer in
                    String(cString: pointer)
                }

                let type = FileInfo.FileType(d_type: systemEntry.pointee.d_type)

                return .init(path: rootPath.appending(name), type: type)

            #endif

        }


        private func _clean() throws(FileError) {

            guard !ended else { return }

            #if canImport(WinSDK)
            
            SetLastError(DWORD(NO_ERROR))
            if let findHandle {
                try execThrowingCFunction(operationDescription: .readingDirEntries(at: rootPath)) {
                    FindClose(findHandle)
                }
            }

            #else

            try execThrowingCFunction(operationDescription: .readingDirEntries(at: rootPath)) {
                closedir(.init(dirStream))
            }

            #endif

        }


        private mutating func endIter() throws(FileError) {
            defer {
                ended = true
            }
            try _clean()
        }

    }

}



extension OpaquePointer {
    fileprivate init(_ ptr: OpaquePointer) {
        self = ptr
    }
}