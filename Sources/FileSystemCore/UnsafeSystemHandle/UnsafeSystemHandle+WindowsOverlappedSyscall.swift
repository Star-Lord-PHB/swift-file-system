#if canImport(WinSDK)

import SystemPackage
import WinSDK



/// Wrapper of the Windows OVERLAPPED structure for positional and asynchronous I/O operations.
public struct WindowsOverlapped: ~Copyable {

    package var systemOverlapped: UnsafeOwnedMutableAutoPointer<OVERLAPPED>

    public init(offset: Int64 = 0, eventHandle: WinSDK.HANDLE? = nil) {
        var systemOverlapped = OVERLAPPED()
        systemOverlapped.Offset = DWORD(UInt64(bitPattern: offset) & 0xFFFFFFFF)
        systemOverlapped.OffsetHigh = DWORD((UInt64(bitPattern: offset) >> 32) & 0xFFFFFFFF)
        systemOverlapped.hEvent = eventHandle
        self.systemOverlapped = UnsafeOwnedMutableAutoPointer<OVERLAPPED>.swiftAllocate(capacity: 1)
        self.systemOverlapped.pointee = consume systemOverlapped
    }

    deinit {
        self.systemOverlapped.deallocate()
    }

    /// The offset in the file to perform the I/O operation at.
    public var offset: Int64 {
        get { Int64(bitPattern: UInt64(self.systemOverlapped.pointee.Offset) | (UInt64(self.systemOverlapped.pointee.OffsetHigh) << 32)) }
        set {
            self.systemOverlapped.pointee.Offset = DWORD(UInt64(bitPattern: newValue) & 0xFFFFFFFF)
            self.systemOverlapped.pointee.OffsetHigh = DWORD((UInt64(bitPattern: newValue) >> 32) & 0xFFFFFFFF)
        }
    }

    public var eventHandle: WinSDK.HANDLE? {
        get { self.systemOverlapped.pointee.hEvent }
        set { self.systemOverlapped.pointee.hEvent = newValue }
    }

    /// Read-only access the underlying OVERLAPPED structure in a closure.
    /// - Parameter body: A closure for accessing the underlying OVERLAPPED structure.
    public func withUnsafeSystemOverlapped<T: ~Copyable, E: Error>(_ body: (UnsafePointer<OVERLAPPED>) throws(E) -> T) throws(E) -> T {
        return try body(self.systemOverlapped.unsafeRawPtr)
    }

    /// Mutable access the underlying OVERLAPPED structure in a closure.
    /// - Parameter body: A closure for accessing the underlying OVERLAPPED structure.
    public mutating func withUnsafeMutableSystemOverlapped<T: ~Copyable, E: Error>(_ body: (UnsafeMutablePointer<OVERLAPPED>) throws(E) -> T) throws(E) -> T {
        return try body(self.systemOverlapped.unsafeRawPtr)
    }
    
}



/// Wrapper of an Windows OVERLAPPED structure that is currently in use by an ongoing I/O operation. 
public struct WindowsPendingOverlapped: ~Copyable, ~Escapable {

    private let systemOverlapped: UnsafeMutablePointer<OVERLAPPED>
    private let associatedRawHandle: UnsafeSystemHandle.SystemHandleType

    /// Create a `WindowsPendingOverlapped` from an `WindowsOverlapped` with ongoing I/O operation 
    /// on the specified file hanele
    /// 
    /// - Parameters:
    ///   - overlapped: The `WindowsOverlapped` used to start the I/O operation.
    ///   - associatedHandle: The `UnsafeSystemHandle` that the I/O operation is performed on.
    @_lifetime(&overlapped, borrow associatedHandle)
    public init(overlapped: inout WindowsOverlapped, associatedHandle: borrowing UnsafeSystemHandle) {
        self.systemOverlapped = overlapped.systemOverlapped.unsafeRawPtr
        self.associatedRawHandle = associatedHandle.unsafeRawHandle
    }

    deinit {
        precondition(false, "WindowsPendingOverlapped being deinitialized automatically without explicitly being waited")
    }

    /// Waits for the I/O operation to complete.
    /// - Returns: The number of bytes transferred.
    public consuming func wait() throws(LowLevelError) -> Int64 {
        let systemOverlapped = self.systemOverlapped
        let associatedRawHandle = self.associatedRawHandle
        discard self
        var bytesTransferred = 0 as DWORD
        try execThrowingCFunction {
            GetOverlappedResult(associatedRawHandle, systemOverlapped, &bytesTransferred, true)
        }
        return Int64(bytesTransferred)
    }

    /// Read-only access the underlying OVERLAPPED structure in a closure.
    /// - Parameter body: A closure for accessing the underlying OVERLAPPED structure.
    public func withUnsafeSystemOverlapped<T: ~Copyable, E: Error>(_ body: (UnsafePointer<OVERLAPPED>) throws(E) -> T) throws(E) -> T {
        return try body(self.systemOverlapped)
    }

    /// Mutable access the underlying OVERLAPPED structure in a closure.
    /// - Parameter body: A closure for accessing the underlying OVERLAPPED structure.
    /// 
    /// > Warning: 
    /// > Mutating the OVERLAPPED value that is in use by an ongoing I/O operation is extremely dangerous, 
    /// > use this function only if you are absolutely sure of what you are doing.
    @_lifetime(self: copy self)
    public mutating func withUnsafeMutableSystemOverlapped<T: ~Copyable, E: Error>(_ body: (UnsafeMutablePointer<OVERLAPPED>) throws(E) -> T) throws(E) -> T {
        return try body(self.systemOverlapped)
    }

}



extension UnsafeSystemHandle {

    /// Starts an overlapped I/O operation on the file handle with the specified `WindowsOverlapped` structure.
    /// 
    /// - Parameters:
    ///   - overlapped: The `WindowsOverlapped` structure to use for the I/O operation.
    ///   - body: A closure that performs the I/O operation using the raw file handle and the the 
    ///           `OVERLAPPED` structure.
    /// - Returns: A `WindowsPendingOverlapped` associated with the ongoing I/O operation.
    @_lifetime(&overlapped, borrow self)
    public func unsafeStartOverlappedOperation<E: Error>(
        with overlapped: inout WindowsOverlapped,
        _ body: (_ rawHandle: UnsafeSystemHandle.SystemHandleType, _ overlappedPtr: UnsafeMutablePointer<OVERLAPPED>) throws(E) -> Void
    ) throws(E) -> WindowsPendingOverlapped {
        try body(unsafeRawHandle, overlapped.systemOverlapped.unsafeRawPtr)
        return .init(overlapped: &overlapped, associatedHandle: self)
    }



    /// Reads data from the file handle at the offset specified by the `WindowsOverlapped` into the 
    /// provided buffer.
    /// 
    /// - Parameters:
    ///   - buffer: The buffer to receive the data read from the file handle.
    ///   - overlapped: The `WindowsOverlapped` structure to use for the read operation.
    /// - Returns: A `WindowsPendingOverlapped` associated with the ongoing read operation.
    /// 
    /// - Note: If the handle is opened in synchronous mode, this operation will modify the file pointer,
    ///         otherwise the file pointer will not be modified.
    @_lifetime(&overlapped, borrow buffer, borrow self)
    public func read(
        into buffer: UnsafeMutableRawBufferPointer,
        overlapped: inout WindowsOverlapped
    ) throws(LowLevelError) -> WindowsPendingOverlapped {

        // lpNumberOfBytesRead stays nil: the count comes from GetOverlappedResult, and for an
        // asynchronous handle the kernel may write through this pointer after ReadFile has returned.
        // Passing nil is valid whenever lpOverlapped is not nil.
        return try unsafeStartOverlappedOperation(with: &overlapped) { (rawHandle, overlappedPtr) throws(LowLevelError) in
            if ReadFile(rawHandle, buffer.baseAddress, DWORD(buffer.count), nil, overlappedPtr) == false {
                let errorCode = GetLastError()
                guard errorCode == ERROR_IO_PENDING else {
                    throw .init(rawSystemCode: errorCode)!
                }
            }
        }

    }
    
    
    /// Reads data from the file handle at the offset specified by the `WindowsOverlapped` into the 
    /// provided buffer.
    /// 
    /// - Parameters:
    ///   - buffer: The buffer to receive the data read from the file handle.
    ///   - overlapped: The `WindowsOverlapped` structure to use for the read operation.
    /// - Returns: A `WindowsPendingOverlapped` associated with the ongoing read operation.
    /// 
    /// - Note: If the handle is opened in synchronous mode, this operation will modify the file pointer,
    ///         otherwise the file pointer will not be modified.
    @_lifetime(&overlapped, borrow buffer, borrow self)
    public func read(
        into buffer: UnsafeMutableRawBufferPointer.SubSequence,
        overlapped: inout WindowsOverlapped
    ) throws(LowLevelError) -> WindowsPendingOverlapped {
        let rebasedBuffer = UnsafeMutableRawBufferPointer(rebasing: buffer)
        return try _overrideLifetime(
            read(into: rebasedBuffer, overlapped: &overlapped),
            borrowing: buffer
        )
    }
    

    /// Reads data from the file handle at the offset specified by the `WindowsOverlapped` into the 
    /// provided buffer.
    /// 
    /// - Parameters:
    ///   - buffer: The buffer to receive the data read from the file handle.
    ///   - overlapped: The `WindowsOverlapped` structure to use for the read operation.
    /// - Returns: A `WindowsPendingOverlapped` associated with the ongoing read operation.
    /// 
    /// - Note: If the handle is opened in synchronous mode, this operation will modify the file pointer,
    ///         otherwise the file pointer will not be modified.
    @_lifetime(&overlapped, &buffer, borrow self)
    public func read(
        into buffer: inout MutableRawSpan,
        overlapped: inout WindowsOverlapped
    ) throws(LowLevelError) -> WindowsPendingOverlapped {

        let lengthToRead = buffer.byteCount

        return try unsafeStartOverlappedOperation(with: &overlapped) { (rawHandle, overlappedPtr) throws(LowLevelError) in
            let result = buffer.withUnsafeMutableBytes { ptr in
                ReadFile(rawHandle, ptr.baseAddress, DWORD(lengthToRead), nil, overlappedPtr)
            }
            if result == false {
                let errorCode = GetLastError()
                guard errorCode == ERROR_IO_PENDING else {
                    throw .init(rawSystemCode: errorCode)!
                }
            }
        }
        
    }


    /// Reads data from the file handle at the offset specified by the `WindowsOverlapped` into the 
    /// provided buffer.
    /// 
    /// - Parameters:
    ///   - buffer: The buffer to receive the data read from the file handle.
    ///   - overlapped: The `WindowsOverlapped` structure to use for the read operation.
    /// - Returns: A `WindowsPendingOverlapped` associated with the ongoing read operation.
    /// 
    /// - Note: If the handle is opened in synchronous mode, this operation will modify the file pointer,
    ///         otherwise the file pointer will not be modified.
    @_lifetime(&overlapped, copy buffer, borrow self)
    public func read(
        into buffer: consuming MutableRawSpan,
        overlapped: inout WindowsOverlapped
    ) throws(LowLevelError) -> WindowsPendingOverlapped {

        let lengthToRead = buffer.byteCount

        return try unsafeStartOverlappedOperation(with: &overlapped) { (rawHandle, overlappedPtr) throws(LowLevelError) in
            let result = buffer.withUnsafeMutableBytes { ptr in
                ReadFile(rawHandle, ptr.baseAddress, DWORD(lengthToRead), nil, overlappedPtr)
            }
            if result == false {
                let errorCode = GetLastError()
                guard errorCode == ERROR_IO_PENDING else {
                    throw .init(rawSystemCode: errorCode)!
                }
            }
        }

    }


    /// Write data from the provided buffer to the file handle at the offset specified by the `WindowsOverlapped`.
    /// 
    /// - Parameters:
    ///   - buffer: The buffer containing the data to write to the file handle.
    ///   - overlapped: The `WindowsOverlapped` structure to use for the write operation.
    /// - Returns: A `WindowsPendingOverlapped` associated with the ongoing write operation.
    /// 
    /// - Note: If the handle is opened in synchronous mode, this operation will modify the file pointer,
    ///         otherwise the file pointer will not be modified.
    @_lifetime(&overlapped, borrow buffer, borrow self)
    public func write(contentsOf buffer: UnsafeRawBufferPointer, overlapped: inout WindowsOverlapped) throws(LowLevelError) -> WindowsPendingOverlapped {

        return try unsafeStartOverlappedOperation(with: &overlapped) { (rawHandle, overlappedPtr) throws(LowLevelError) in
            if WriteFile(rawHandle, buffer.baseAddress, DWORD(buffer.count), nil, overlappedPtr) == false {
                let errorCode = GetLastError()
                guard errorCode == ERROR_IO_PENDING else {
                    throw .init(rawSystemCode: errorCode)!
                }
            }
        }

    }
    
    
    /// Write data from the provided buffer to the file handle at the offset specified by the `WindowsOverlapped`.
    /// 
    /// - Parameters:
    ///   - buffer: The buffer containing the data to write to the file handle.
    ///   - overlapped: The `WindowsOverlapped` structure to use for the write operation.
    /// - Returns: A `WindowsPendingOverlapped` associated with the ongoing write operation.
    /// 
    /// - Note: If the handle is opened in synchronous mode, this operation will modify the file pointer,
    ///         otherwise the file pointer will not be modified.
    @_lifetime(&overlapped, borrow buffer, borrow self)
    public func write(contentsOf buffer: UnsafeRawBufferPointer.SubSequence, overlapped: inout WindowsOverlapped) throws(LowLevelError) -> WindowsPendingOverlapped {
        let rebasedBuffer = UnsafeRawBufferPointer(rebasing: buffer)
        return try _overrideLifetime(
            write(contentsOf: rebasedBuffer, overlapped: &overlapped),
            borrowing: buffer
        )
    }


    /// Write data from the provided buffer to the file handle at the offset specified by the `WindowsOverlapped`.
    /// 
    /// - Parameters:
    ///   - buffer: The buffer containing the data to write to the file handle.
    ///   - overlapped: The `WindowsOverlapped` structure to use for the write operation.
    /// - Returns: A `WindowsPendingOverlapped` associated with the ongoing write operation.
    /// 
    /// - Note: If the handle is opened in synchronous mode, this operation will modify the file pointer,
    ///         otherwise the file pointer will not be modified.
    @_lifetime(&overlapped, copy buffer, borrow self)
    public func write(contentsOf buffer: RawSpan, overlapped: inout WindowsOverlapped) throws(LowLevelError) -> WindowsPendingOverlapped {

        return try unsafeStartOverlappedOperation(with: &overlapped) { (rawHandle, overlappedPtr) throws(LowLevelError) in
            let result = buffer.withUnsafeBytes { ptr in
                WriteFile(rawHandle, ptr.baseAddress, DWORD(buffer.byteCount), nil, overlappedPtr)
            }
            if result == false {
                let errorCode = GetLastError()
                guard errorCode == ERROR_IO_PENDING else {
                    throw .init(rawSystemCode: errorCode)!
                }
            }
        }

    }

}
#endif
