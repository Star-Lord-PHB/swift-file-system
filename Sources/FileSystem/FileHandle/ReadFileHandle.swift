import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
#endif


public struct ReadFileHandle: ~Copyable, ReadFileHandleProtocol {

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



extension ReadFileHandle {

    public init(forFileAt path: FilePath) throws(FileError) {

        #if canImport(WinSDK)

        fatalError("Not implemented")

        #else

        let handle = open(path.string, O_RDONLY)
        guard handle >= 0 else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }

        self.init(unsafeSystemHandle: handle, path: path)

        #endif

    }


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileSeekWhence = .beginning) throws(FileError) -> Int64 {
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



extension ReadFileHandle {

    public func read(fromOffset offset: Int64?, length: Int64?, into buffer: inout ByteBuffer) throws(FileError) {

    #if canImport(WinSDK)

        fatalError("Not implemented")

    #else

        let lengthToRead = min(buffer.count, length.map { Int($0) } ?? buffer.count)

        let bytesRead = if let offset {
            buffer.withUnsafeMutableBytes { bufferPtr in
                pread(handle, bufferPtr.baseAddress, lengthToRead, .init(offset))
            }
        } else {
            buffer.withUnsafeMutableBytes { bufferPtr in
                Foundation.read(handle, bufferPtr.baseAddress, lengthToRead)
            }
        }

        if bytesRead < 0 {
            try FileError.assertError(operationDescription: .readingHandle(at: path, offset: offset, length: Int64(lengthToRead)))
        }

    #endif

    }

}