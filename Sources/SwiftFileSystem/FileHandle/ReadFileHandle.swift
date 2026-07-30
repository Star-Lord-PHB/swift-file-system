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
    // Here this mutex is not used for thread safety, but to allow mutable states within nonmutating methods
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

        var openOptions = UnsafeSystemHandle.OpenOptions(
            access: .readOnly(), 
            noFollow: options.noFollow, 
            closeOnExec: options.closeOnExec
        )

        #if canImport(WinSDK)
        openOptions.noBlocking = true
        #else 
        openOptions.noBlocking = false
        #endif

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.open(at: path,  openOptions: openOptions)
        } kindConversion: { error in 
            switch error.systemCode {
                #if canImport(WinSDK)
                case .accessDenied: .windows.permissionDeniedOrIsADirectory
                #endif
                default: error.kind
            }
        }

        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            switch try handle.type() {
                case .symlink: throw .init(kind: .pathResolutionFailed)
                case .directory: throw .init(kind: .isADirectory)
                default: break
            }
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) throws(PlatformError) -> Int64 {

        #if canImport(WinSDK)

        switch whence {
            case .beginning:
                return try _currentOffset.withLock { (currentOffset) throws(PlatformError) in
                    currentOffset = try trySeek(from: 0, by: offset, operation: .seekHandle(originalPath: path))
                    return currentOffset
                }
            case .current:
                return try _currentOffset.withLock { (currentOffset) throws(PlatformError) in
                    currentOffset = try trySeek(from: currentOffset, by: offset, operation: .seekHandle(originalPath: path))
                    return currentOffset
                }
            case .end:
                var size = LARGE_INTEGER(QuadPart: 0)
                try execThrowingCFunction(operation: .seekHandle(originalPath: path)) {
                    GetFileSizeEx(handle.unsafeRawHandle, &size)
                }
                return try _currentOffset.withLock { (currentOffset) throws(PlatformError) in
                    currentOffset = try trySeek(from: size.QuadPart, by: offset, operation: .seekHandle(originalPath: path))
                    return currentOffset
                }
        }

        #else 

        return try catchLowLevelError(operation: .seekHandle(originalPath: path)) { () throws(LowLevelError) in
            try handle.seek(to: offset, from: whence)
        }
        
        #endif
    }


    public consuming func close() throws(PlatformError) {
        do {
            try handle.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension ReadFileHandle {

    @discardableResult
    public func read(fromOffset offset: Int64?, length: Int64?, into buffer: inout ByteBuffer) throws(PlatformError) -> Int64 {

        let lengthToRead = min(Int64(buffer.count), length ?? Int64(buffer.count))

        #if canImport(WinSDK)

        if let offset, offset < 0 {
            throw .init(lowLevelError: .init(kind: .invalidInput), operation: .readHandle(originalPath: path))
        }

        return try catchLowLevelError(operation: .readHandle(originalPath: path)) { () throws(LowLevelError) in
            do throws(LowLevelError) {
                if let offset {
                    return try buffer.withUnsafeMutableBytes { (bufferPtr) throws(LowLevelError) in
                        var overlapped = WindowsOverlapped(offset: offset)
                        let pendingOverlapped = try handle.read(into: bufferPtr, length: lengthToRead, overlapped: &overlapped)
                        return try handle.waitForOverlappedResult(pendingOverlapped)
                    }
                } else {
                    let currentOffset = _currentOffset.withLock(\.self)
                    let bytesRead = try buffer.withUnsafeMutableBytes { (bufferPtr) throws(LowLevelError) in
                        var overlapped = WindowsOverlapped(offset: currentOffset)
                        let pendingOverlapped = try handle.read(into: bufferPtr, length: lengthToRead, overlapped: &overlapped) 
                        return try handle.waitForOverlappedResult(pendingOverlapped)
                    }
                    _currentOffset.withLock {
                        $0 = currentOffset + bytesRead
                    }
                    return bytesRead
                }
            } catch let error where error.systemCode == .handleEOF {
                return 0
            }
        }

        #else

        return try catchLowLevelError(operation: .readHandle(originalPath: path)) { () throws(LowLevelError) in 
            if let offset {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(LowLevelError) in
                    try handle.pread(into: bufferPtr, from: offset, length: lengthToRead)
                }
            } else {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(LowLevelError) in
                    try handle.read(into: bufferPtr, length: lengthToRead)
                }
            }
        }

        #endif

    }

}
