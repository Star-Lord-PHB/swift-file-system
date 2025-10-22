import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
#endif


public struct DirectoryHandle: ~Copyable, DirectoryHandleProtocol {

    fileprivate let handle: SystemHandleType 
    fileprivate var isClosed: Bool = false 
    public let path: FilePath


    init(unsafeSystemHandle: SystemHandleType, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }


    private func _close() throws(FileError) {
        if !isClosed {
            #if canImport(WinSDK)
            fatalError("Not implemented")
            #else 
            try execThrowingCFunction(operationDescription: .closingHandle(at: path)) {
                Foundation.close(handle)
            }
            #endif 
        }
    }


    deinit {
        try? _close()
    }


    public consuming func close() throws(FileError) {
        try _close()
        isClosed = true
    }


    public func withUnsafeSystemHandle<R, E: Error>(_ body: (SystemHandleType) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension DirectoryHandle {

    public init(forDirAt path: FilePath) throws(FileError) {

        #if canImport(WinSDK)

        fatalError("Not implemented")

        #else

        let handle = open(path.string, O_RDONLY | O_DIRECTORY)
        guard handle >= 0 else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }
        self.init(unsafeSystemHandle: handle, path: path)
        
        #endif

    }


    public func directEntries() throws(FileError) -> [DirectoryEntry] {

        try DirectoryEntrySequence(handle: self, recursive: false)
            .map { entry throws(FileError) in
                switch entry {
                    case .success(let dirEntry):    return dirEntry
                    case .failure(let error):       throw error
                }
            }

    }


    @_lifetime(borrow self)
    public func entrySequence(recursive: Bool = false) throws(FileError) -> DirectoryEntrySequenceType {
        return DirectoryEntrySequence(handle: self, recursive: recursive)
    }

}