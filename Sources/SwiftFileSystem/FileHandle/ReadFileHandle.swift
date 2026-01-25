import SystemPackage
import FileSystemCore

#if canImport(WinSDK)
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
        get throws(PlatformError) {
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

    public init(forFileAt path: FilePath, options: FileOperationOptions.OpenForReading = .init()) throws(PlatformError) {

        var openOptions = options.unsafeSystemFileOpenOptions()

        #if canImport(WinSDK)
        openOptions.noBlocking = true
        #else 
        openOptions.noBlocking = false
        #endif

        let handle = try catchSystemError(operation: .open(path)) { () throws(SystemError) in
            try UnsafeSystemHandle.open(
                at: path, 
                openOptions: openOptions
            )
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) throws(PlatformError) -> Int64 {

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

        return try catchSystemError(operation: .seekHandle(originalPath: path)) { () throws(SystemError) in
            try handle.seek(to: offset, from: whence)
        }
        
        #endif
    }


    public consuming func close() throws(PlatformError) {
        do {
            try handle.close()
        } catch {
            throw .init(systemError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension ReadFileHandle {

    public func read(fromOffset offset: Int64?, length: Int64?, into buffer: inout ByteBuffer) throws(PlatformError) {

        let lengthToRead = min(Int64(buffer.count), length ?? Int64(buffer.count))

    #if canImport(WinSDK)

        try catchSystemError(operationDescription: .readingHandle(at: path, offset: offset, length: lengthToRead)) { () throws(SystemError) in
            if let offset {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    var overlapped = WindowsOverlapped(offset: offset)
                    let pendingOverlapped = try handle.read(into: bufferPtr, length: lengthToRead, overlapped: &overlapped)
                    _ = try handle.waitForOverlappedResult(pendingOverlapped)
                }
            } else {
                let currentOffset = _currentOffset.withLock(\.self)
                let bytesRead = try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    var overlapped = WindowsOverlapped(offset: currentOffset)
                    let pendingOverlapped = try handle.read(into: bufferPtr, length: lengthToRead, overlapped: &overlapped) 
                    return try handle.waitForOverlappedResult(pendingOverlapped)
                }
                _currentOffset.withLock {
                    $0 = currentOffset + bytesRead
                }
            }
        }

    #else

        try catchSystemError(operation: .readHandle(originalPath: path)) { () throws(SystemError) in 
            if let offset {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    _ = try handle.pread(into: bufferPtr, from: offset, length: lengthToRead)
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