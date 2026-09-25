//
//  WriteFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



/// A protocol for file handles that support synchronizing with the underlying device.
public protocol PersistentFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    /// Synchronizes the file handle with the underlying device.
    func synchronize() throws(PlatformError)
}



extension PersistentFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {
    public func synchronize() throws(PlatformError) {
        try withUnsafeSystemHandle(operation: .syncHandle(originalPath: path)) { (handle) throws(LowLevelError) in
            try handle.fsync()
        }
    }
}



/// A protocol for file handles that support resizing.
public protocol ResizableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    /// Resizes the file to the specified size.
    func resize(to size: Int64) throws(PlatformError)
}



extension ResizableFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    public func resize(to size: Int64) throws(PlatformError) {
        return try withUnsafeSystemHandle(operation: .resizeHandle(originalPath: path)) { (handle) throws(LowLevelError) in
            try handle.truncate(to: size)
        }
    }

}



/// A protocol for file handles that support positional writing operations.
public protocol PositionalWriteFileHandleProtocol: ~Copyable, ~Escapable, ResizableFileHandleProtocol {

    /// Writes the provided bytes into the file handle at the specified offset.
    /// - Parameters:
    ///   - buffer: The bytes to write into the file handle.
    ///   - offset: The offset relative to the beginning of the file to write to.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    func write(_ buffer: RawSpan, toOffset offset: Int64) throws(PlatformError) -> Int64

}



extension PositionalWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Writes the provided bytes into the file handle at the specified offset.
    /// - Parameters:
    ///   - buffer: The bytes to write into the file handle.
    ///   - offset: The offset relative to the beginning of the file to write to.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    public func write(_ buffer: ByteBuffer, toOffset offset: Int64) throws(PlatformError) -> Int64 {
        return try write(buffer.bytes, toOffset: offset)
    }

}



extension PositionalWriteFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    @discardableResult
    public func write(_ buffer: RawSpan, toOffset offset: Int64) throws(PlatformError) -> Int64 {
        #if canImport(WinSDK)
        // A negative OVERLAPPED offset is the append-at-end sentinel for WriteFile; reject it up
        // front like POSIX pwrite reports EINVAL instead of silently appending.
        guard offset >= 0 else {
            throw .init(lowLevelError: .init(kind: .invalidInput), operation: .writeHandle(originalPath: path))
        }
        #endif
        return try self.withUnsafeSystemHandle(operation: .writeHandle(originalPath: path)) { handle throws(LowLevelError) in
            try handle.pwrite(contentsOf: buffer, to: offset)
        }
    }

}



/// A protocol for file handles that support sequential writing.
public protocol SequentialWriteFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    /// Writes the provided bytes into the file handle at the current position of the file pointer.
    /// - Parameter bytes: The bytes to write into the file handle.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    func write(_ bytes: RawSpan) throws(PlatformError) -> Int64

}



extension SequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Writes the provided bytes into the file handle at the current position of the file pointer.
    /// - Parameter bytes: The bytes to write into the file handle.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    public func write(_ bytes: ByteBuffer) throws(PlatformError) -> Int64 {
        return try write(bytes.bytes)
    }

}



extension SequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    @discardableResult
    public func write(_ bytes: RawSpan) throws(PlatformError) -> Int64 {
        return try self.withUnsafeSystemHandle(operation: .writeHandle(originalPath: path)) { handle throws(LowLevelError) in
            try handle.write(contentsOf: bytes)
        }
    }

}




/// A protocol for file handles that support atomically appending data to the end of the file.
public protocol AppendableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    /// Appends the provided bytes to the end of the file handle atomically.
    /// - Parameter bytes: The bytes to append to the end of the file handle.
    /// - Returns: The number of bytes actually appended to the file handle.
    @discardableResult
    func append(_ bytes: RawSpan) throws(PlatformError) -> Int64

}



extension AppendableFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Appends the provided bytes to the end of the file handle atomically.
    /// - Parameter bytes: The bytes to append to the end of the file handle.
    /// - Returns: The number of bytes actually appended to the file handle.
    @discardableResult
    public func append(_ bytes: ByteBuffer) throws(PlatformError) -> Int64 {
        return try append(bytes.bytes)
    }

}
