import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
import Synchronization
#endif


public struct ReadFileHandle: ~Copyable, ReadFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle 
    public let path: FilePath

    #if canImport(WinSDK)
    // On windows, there is not direct way to allow random access (similar to pread in POSIX) 
    // while allowing accessing with system file pointer. So we track the current offset manually.
    private let _currentOffset: Mutex<Int64> = Mutex(0)
    public var currentOffset: Int64 {
        get throws(FileError) {
            _currentOffset.withLock(\.self)
        }
    }
    #endif 


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension ReadFileHandle {

    public init(forFileAt path: FilePath, options: FileOperationOptions.OpenForReading = .init()) throws(FileError) {

        #if canImport(WinSDK)
        let noBlocking = true 
        #else 
        let noBlocking = false
        #endif

        let handle = try catchSystemError(operationDescription: .openingHandle(forFileAt: path)) { () throws(SystemError) in
            try UnsafeSystemHandle.open(
                at: path, 
                openOptions: options.unsafeSystemFileOpenOptions(noBlocking: noBlocking)
            )
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: UnsafeSystemHandle.SeekWhence = .beginning) throws(FileError) -> Int64 {

        #if canImport(WinSDK)

        switch whence {
            case .beginning:
                return _currentOffset.withLock { 
                    $0 = offset 
                    return $0
                }
            case .current:
                return _currentOffset.withLock { 
                    $0 += offset 
                    return $0
                }
            case .end:
                var size = LARGE_INTEGER(QuadPart: 0)
                try execThrowingCFunction(operationDescription: .seekingHandle(at: path, to: offset, relativeTo: whence)) {
                    GetFileSizeEx(handle.unsafeRawHandle, &size)
                }
                return _currentOffset.withLock {
                    $0 = size.QuadPart + offset
                    return $0
                }
        }

        #else 

        return try catchSystemError(operationDescription: .seekingHandle(at: path, to: offset, relativeTo: whence)) { () throws(SystemError) in
            try handle.seek(to: offset, from: whence)
        }
        
        #endif
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



extension ReadFileHandle {

    public func read(fromOffset offset: Int64?, length: Int64?, into buffer: inout ByteBuffer) throws(FileError) {

        let lengthToRead = min(Int64(buffer.count), length ?? Int64(buffer.count))

    #if canImport(WinSDK)

        try catchSystemError(operationDescription: .readingHandle(at: path, offset: offset, length: lengthToRead)) { () throws(SystemError) in
            if let offset {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    _ = try handle.withWindowsOverlapped { (overlapped) throws(SystemError) in
                        overlapped.offset = offset
                        try handle.read(into: bufferPtr, length: lengthToRead, overlapped: &overlapped)
                    }
                }
            } else {
                let currentOffset = _currentOffset.withLock(\.self)
                let bytesRead = try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    try handle.withWindowsOverlapped { (overlapped) throws(SystemError) in
                        overlapped.offset = currentOffset
                        try handle.read(into: bufferPtr, length: lengthToRead, overlapped: &overlapped)
                    }
                }
                _currentOffset.withLock {
                    $0 = currentOffset + bytesRead
                }
            }
        }

    #else

        try catchSystemError(operationDescription: .readingHandle(at: path, offset: offset, length: lengthToRead)) { () throws(SystemError) in 
            if let offset {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    _ = try handle.pread(into: bufferPtr, length: lengthToRead, from: offset)
                }
            } else {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    _ = try handle.read(into: bufferPtr, length: lengthToRead)
                }
            }
        }

    #endif

    }

}