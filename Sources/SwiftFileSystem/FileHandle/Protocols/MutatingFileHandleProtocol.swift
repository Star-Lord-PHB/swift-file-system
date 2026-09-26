//
//  MutatingFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import FileSystemCore
import SystemPackage



/// A protocol for file handles that support seeking the file pointer as a mutating operation. 
/// 
/// This protocol is useful for file handle implementations maintaining the file pointer manually as a state 
/// instead of relying on the native file system.
public protocol MutatingSeekableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    /// Seeks the file pointer to a new position.
    /// - Parameters:
    ///   - offset: The offset to seek to.
    ///   - whence: The relative starting point for the offset.
    /// - Returns: The new position of the file pointer after seeking.
    @discardableResult
    @_lifetime(self: copy self)
    mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64
    /// Gets the current position of the file pointer, relative to the beginning of the file.
    var currentOffset: Int64 { get throws(PlatformError) }
}



/// A protocol for file handles that support sequential reading as a mutating operation.
/// 
/// This protocol is useful for file handle implementations maintaining the file pointer manually as a state 
/// instead of relying on the native file system.
public protocol MutatingSequentialReadFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    /// Reads data from the file handle at the current position of the file pointer into the provided buffer.
    /// - Parameter buffer: The buffer to receive the read data, 
    ///                     whose size is the max number of bytes to read.
    /// - Returns: The number of bytes read into the buffer.
    @_lifetime(self: copy self)
    @_lifetime(buffer: copy buffer)
    mutating func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64
}



extension MutatingSequentialReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Reads data from the file handle at the current position of the file pointer into the provided buffer.
    /// - Parameter buffer: The buffer to receive the read data, 
    ///                     whose size is the max number of bytes to read.
    /// - Returns: The number of bytes read into the buffer.
    @_lifetime(self: copy self)
    public mutating func read(into buffer: consuming MutableRawSpan) throws(PlatformError) -> Int64 {
        return try self.read(into: &buffer)
    }

    /// Reads data from the file handle at the current position of the file pointer into the provided buffer.
    /// - Parameter 
    ///   - buffer: The buffer to receive the read data.
    ///   - bufferRange: The range of the buffer to be filled with the read data.
    /// - Returns: The number of bytes read into the buffer.
    @_lifetime(self: copy self)
    public mutating func read(into buffer: inout ByteBuffer, at bufferRange: some RangeExpression<Int> = 0...) throws(PlatformError) -> Int64 {
        return try self.read(into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }

    /// Reads upto specified number of bytes from the file handle at the current position of the file pointer
    /// and returns them as a ``ByteBuffer``.
    /// - Parameter length: The maximum number of bytes to read.
    /// - Returns: A ``ByteBuffer`` containing the read data, whose size is the actual number of bytes read.
    @_lifetime(self: copy self)
    public mutating func read(length: Int64) throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        let bytesRead = try read(into: &buffer, at: ..<Int(length))
        buffer.removeLast(Int(Int64(buffer.count) - bytesRead))
        return buffer
    }

}



/// A protocol for file handles that support sequential writing as a mutating operation.
/// 
/// This protocol is useful for file handle implementations maintaining the file pointer manually as a state 
/// instead of relying on the native file system.
public protocol MutatingSequentialWriteFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    /// Writes the provided bytes into the file handle at the current position of the file pointer.
    /// - Parameter bytes: The bytes to write into the file handle.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    @_lifetime(self: copy self)
    mutating func write(_ bytes: RawSpan) throws(PlatformError) -> Int64
}



extension MutatingSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {
    /// Writes the provided bytes into the file handle at the current position of the file pointer.
    /// - Parameter bytes: The bytes to write into the file handle.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    @_lifetime(self: copy self)
    public mutating func write(_ bytes: ByteBuffer) throws(PlatformError) -> Int64 {
        return try self.write(bytes.bytes)
    }
}
