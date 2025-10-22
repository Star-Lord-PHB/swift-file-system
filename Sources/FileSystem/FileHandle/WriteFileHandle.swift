import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
#endif


public struct WriteFileHandle: ~Copyable, WriteFileHandleProtocol {

    fileprivate let handle: SystemHandleType 
    fileprivate var isClosed: Bool = false 
    public let path: FilePath


    init(unsafeSystemHandle: SystemHandleType, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }


    deinit {
        try? _close()
    }

}



extension WriteFileHandle {

    public init(forFileAt path: FilePath, options: FileOperationOptions.Write = .editFile()) throws(FileError) {

        #if canImport(WinSDK)

        fatalError("Not implemented")

        #else

        var flags: CInt = O_WRONLY

        switch options.openFile {
            case .direct:     break
            case .truncate: flags |= O_TRUNC
        }

        switch options.createFile {
            case .none:                     break 
            case .some(.createIfMissing):   flags |= O_CREAT
            case .some(.assertMissing):     flags |= O_EXCL | O_CREAT
        }

        let handle = open(path.string, flags, S_IRUSR | S_IWUSR)
        guard handle >= 0 else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }

        self.init(unsafeSystemHandle: handle, path: path)

        #endif

    }


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileSeekWhence) throws(FileError) -> Int64 {
        #if canImport(WinSDK)
        fatalError("Not implemented")
        #else 
        let newOffset = lseek(handle, .init(offset), whence.rawValue)
        guard newOffset >= 0 else {
            try FileError.assertError(operationDescription: .seekingHandle(at: path, to: offset, relativeTo: whence))
        }
        return Int64(newOffset)
        #endif
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


    public consuming func close() throws(FileError) {
        try _close()
        isClosed = true
    }


    public func withUnsafeSystemHandle<R, E: Error>(_ body: (SystemHandleType) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension WriteFileHandle {

    public func write(_ data: some ContiguousBytes, toOffset offset: Int64?) throws(FileError) -> Int64 {

        let count = data.withUnsafeBytes { $0.count }
        
    #if canImport(WinSDK)

        fatalError("Not implemented")

    #else

        let bytesWritten = if let offset {
            data.withUnsafeBytes { bufferPtr in
                pwrite(handle, bufferPtr.baseAddress, count, .init(offset))
            }
        } else {
            data.withUnsafeBytes { bufferPtr in
                Foundation.write(handle, bufferPtr.baseAddress, count)
            }
        }

        if bytesWritten < 0 {
            try FileError.assertError(operationDescription: .writingHandle(at: path, offset: offset, length: Int64(count)))
        }

        return Int64(bytesWritten)

    #endif 

    }


    public func resize(to size: Int64) throws(FileError) {
        
    #if canImport(WinSDK)

        fatalError("Not implemented")

    #else

        try execThrowingCFunction(operationDescription: .resizingHandle(at: path, toSize: size)) {
            ftruncate(handle, .init(size))
        }

    #endif

    }


    public func synchronize() throws(FileError) {
        
    #if canImport(WinSDK)

        fatalError("Not implemented")

    #else

        try execThrowingCFunction(operationDescription: .synchronizingHandle(at: path)) {
            fsync(handle)
        }

    #endif

    }

}