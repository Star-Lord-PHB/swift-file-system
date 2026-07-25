import SystemPackage
import FileSystemCore

#if canImport(WinSDK)
import Synchronization
import WinSDK
#endif


public struct WriteFileHandle: ~Copyable, WriteFileHandleProtocol {

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



extension WriteFileHandle {

    public init(
        forFileAt path: FilePath, 
        options: FileOperationOptions.OpenForWriting = .editFile(), 
        creationPermissions: FilePermissions? = nil
    ) throws(PlatformError) {

        var openOptions = options.unsafeSystemFileOpenOptions()

        #if canImport(WinSDK)
        openOptions.noBlocking = true
        #else 
        openOptions.noBlocking = false
        #endif

        let handle = try catchSystemError(operation: .open(path)) { () throws(SystemError) in
            try UnsafeSystemHandle.open(at: path, openOptions: openOptions, creationPermissions: creationPermissions)
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }


    #if canImport(WinSDK)
    public init(
        forFileAt path: FilePath, 
        options: FileOperationOptions.OpenForWriting = .editFile(), 
        creationPermissions: WindowsSecurityDescriptorView
    ) throws(PlatformError) {

        var openOptions = options.unsafeSystemFileOpenOptions()

        openOptions.noBlocking = true

        let handle = try catchSystemError(operation: .open(path)) { () throws(SystemError) in
            try UnsafeSystemHandle.open(at: path, openOptions: openOptions, creationPermissions: creationPermissions)
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }

    public init(
        forFileAt path: FilePath, 
        options: FileOperationOptions.OpenForWriting = .editFile(), 
        creationPermissions: borrowing WindowsAbsoluteSecurityDescriptor
    ) throws(PlatformError) {
        try self.init(forFileAt: path, options: options, creationPermissions: creationPermissions.view)
    }

    public init(
        forFileAt path: FilePath, 
        options: FileOperationOptions.OpenForWriting = .editFile(), 
        creationPermissions: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) {
        try self.init(forFileAt: path, options: options, creationPermissions: creationPermissions.view)
    }
    #endif


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64 {

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

        try catchSystemError(operation: .seekHandle(originalPath: path)) { () throws(SystemError) in
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



extension WriteFileHandle {

    public func write(_ data: ByteBuffer, toOffset offset: Int64?) throws(PlatformError) -> Int64 {
        
    #if canImport(WinSDK)

        if let offset, offset < 0 {
            throw .init(code: .invalidInput, operation: .writeHandle(originalPath: path))!
        }

        return try data.withUnsafeBytes { (bufferPtr) throws(PlatformError) in
            try catchSystemError(operation: .writeHandle(originalPath: path)) { () throws(SystemError) in
                if let offset {
                    var overlapped = WindowsOverlapped(offset: offset)
                    let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(pendingOverlapped)
                } else {
                    let currentOffset = _currentOffset.withLock(\.self)
                    var overlapped = WindowsOverlapped(offset: currentOffset)
                    let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    let bytesWritten = try handle.waitForOverlappedResult(pendingOverlapped)
                    _currentOffset.withLock {
                        $0 = currentOffset + Int64(bytesWritten)
                    }
                    return Int64(bytesWritten)
                }
            }
        }   

    #else

        return try data.withUnsafeBytes { bufferPtr throws(PlatformError) in
            try catchSystemError(operation: .writeHandle(originalPath: path)) { () throws(SystemError) in
                if let offset {
                    return try handle.pwrite(contentsOf: bufferPtr, to: offset)
                } else {
                    return try handle.write(contentsOf: bufferPtr)
                }
            }
        }

    #endif 

    }


    public func resize(to size: Int64) throws(PlatformError) {
        
        try catchSystemError(operation: .resizeHandle(originalPath: path)) { () throws(SystemError) in
            try handle.truncate(to: size)
        }

    }


    public func synchronize() throws(PlatformError) {
        
        try catchSystemError(operation: .syncHandle(originalPath: path)) { () throws(SystemError) in
            try handle.fsync()
        }

    }

}
