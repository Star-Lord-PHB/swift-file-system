import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
#endif



public struct DirectoryHandle: ~Copyable, DirectoryHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle 
    public let path: FilePath


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension DirectoryHandle {

    public init(forDirAt path: FilePath) throws(FileError) {

        #if canImport(WinSDK)

        let openFlags = DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED | FILE_FLAG_BACKUP_SEMANTICS)

        let handle = path.string.withCString(encodedAs: UTF16.self) { cStr in
            CreateFileW(cStr, GENERIC_READ, DWORD(FILE_SHARE_READ), nil, DWORD(OPEN_EXISTING), openFlags, nil)
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }

        self.init(unsafeSystemHandle: .init(owningRawHandle: handle), path: path)

        #else

        let handle = open(path.string, O_RDONLY | O_DIRECTORY)
        guard handle >= 0 else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }
        self.init(unsafeSystemHandle: .init(owningRawHandle: handle), path: path)
        
        #endif

    }


    public func directEntries() throws(FileError) -> [DirectoryEntry] {
        try ScopedEntrySequence(unsafeSystemHandle: handle, path: path, recursive: false)
            .map { entry throws(FileError) in
                switch entry {
                    case .success(let dirEntry):    return dirEntry
                    case .failure(let error):       throw error
                }
            }
    }


    @_lifetime(borrow self)
    public func entrySequence(recursive: Bool = false) throws(FileError) -> DirectoryEntrySequenceType {
        return ScopedEntrySequence(unsafeSystemHandle: handle, path: path, recursive: recursive)
    }


    public consuming func close() throws(FileError) {
        do {
            try handle.close()
        } catch {
            throw .init(systemError: error, operationDescription: .closingHandle(at: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension DirectoryHandle {

    public struct ScopedEntrySequence: DirectoryEntrySequenceProtocol, ~Escapable, ~Copyable {

        private let handle: UnsafeUnownedSystemHandle
        public let path: FilePath
        public let recursive: Bool


        @_lifetime(immortal)
        init(unsafeSystemHandle: borrowing UnsafeSystemHandle, path: FilePath, recursive: Bool) {
            self.handle = unsafeSystemHandle.unownedHandle()
            self.path = path
            self.recursive = recursive
        }


        @_lifetime(borrow self)
        public func makeIterator() -> Iterator {
            do {
                if recursive {
                    return try DirectoryEntryIterator.recursive(path: path)
                } else {
                    return try DirectoryEntryIterator.direct(unsafeUnownedSystemHandle: handle, path: path)
                }
            } catch {
                return DirectoryEntryIterator.openError(error: error)
            }
        }

    }

}