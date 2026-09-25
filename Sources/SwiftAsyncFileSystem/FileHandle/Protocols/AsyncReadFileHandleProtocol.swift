//
//  AsyncReadFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// A protocol for file handles that support positioanal reading operations.
public protocol AsyncPositionalReadFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    /// Reads data from the file handle at the specified offset into the provided buffer.
    /// - Parameters:
    ///   - offset: The offset relative to the beginning of the file to read from.
    ///   - buffer: The buffer to receive the read data, 
    ///             whose size is the max number of bytes to read.
    /// - Returns: The number of bytes read into the buffer.
    @concurrent
    @_lifetime(buffer: copy buffer)
    func read(fromOffset offset: Int64, into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64

}



extension AsyncPositionalReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Reads data from the file handle at the specified offset into the provided buffer.
    /// - Parameters: 
    ///   - offset: The offset relative to the beginning of the file to read from.
    ///   - buffer: The buffer to receive the read data, 
    ///                     whose size is the max number of bytes to read.
    /// - Returns: The number of bytes read into the buffer.
    @concurrent
    public func read(fromOffset offset: Int64, into buffer: consuming MutableRawSpan) async throws(PlatformError) -> Int64 {
        return try await read(fromOffset: offset, into: &buffer)
    }


    /// Reads data from the file handle at the specified offset into the provided buffer.
    /// - Parameter 
    ///   - offset: The offset relative to the beginning of the file to read from.
    ///   - buffer: The buffer to receive the read data.
    ///   - bufferRange: The range of the buffer to be filled with the read data.
    /// - Returns: The number of bytes read into the buffer.
    @concurrent
    public func read(
        fromOffset offset: Int64,
        into buffer: inout ByteBuffer,
        at bufferRange: some RangeExpression<Int> = 0...
    ) async throws(PlatformError) -> Int64 {
        return try await read(fromOffset: offset, into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }


    /// Reads upto specified number of bytes from the file handle at the specified offset.
    /// and returns them as a ``ByteBuffer``.
    /// - Parameters:
    ///   - offset: The offset relative to the beginning of the file to read from.
    ///   - length: The maximum number of bytes to read.
    /// - Returns: A ``ByteBuffer`` containing the read data, whose size is the actual number of bytes read.
    @concurrent
    public func read(fromOffset offset: Int64, length: Int64) async throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        let bytesRead = try await read(fromOffset: offset, into: &buffer, at: ..<Int(length))
        buffer.removeLast(Int(Int64(buffer.count) - bytesRead))
        return buffer
    }

}



extension AsyncPositionalReadFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    @_lifetime(buffer: copy buffer)
    public func read(fromOffset offset: Int64, into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64 {
        return try await withSyncHandleAdapterInExecutor { adapter throws(PlatformError) in
            try adapter.read(fromOffset: offset, into: &buffer)
        }
        .getThrowingPlatformError(operation: .readHandle(originalPath: path))
    }

}



/// A protocol for file handles that support sequential reading.
public protocol AsyncSequentialReadFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    /// Reads data from the file handle at the current position of the file pointer into the provided buffer.
    /// - Parameter buffer: The buffer to receive the read data, 
    ///                     whose size is the max number of bytes to read.
    /// - Returns: The number of bytes read into the buffer.
    @concurrent
    @_lifetime(buffer: copy buffer)
    func read(into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64

}



extension AsyncSequentialReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Reads data from the file handle at the current position of the file pointer into the provided buffer.
    /// - Parameter buffer: The buffer to receive the read data, 
    ///                     whose size is the max number of bytes to read.
    /// - Returns: The number of bytes read into the buffer.
    @concurrent
    public func read(into buffer: consuming MutableRawSpan) async throws(PlatformError) -> Int64 {
        return try await read(into: &buffer)
    }


    /// Reads data from the file handle at the current position of the file pointer into the provided buffer.
    /// - Parameter 
    ///   - buffer: The buffer to receive the read data.
    ///   - bufferRange: The range of the buffer to be filled with the read data.
    /// - Returns: The number of bytes read into the buffer.
    @concurrent
    public func read(into buffer: inout ByteBuffer, at bufferRange: some RangeExpression<Int> = 0...) async throws(PlatformError) -> Int64 {
        return try await read(into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }


    /// Reads upto specified number of bytes from the file handle at the current position of the file pointer
    /// and returns them as a ``ByteBuffer``.
    /// - Parameter length: The maximum number of bytes to read.
    /// - Returns: A ``ByteBuffer`` containing the read data, whose size is the actual number of bytes read.
    @concurrent
    public func read(length: Int64) async throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        let bytesRead = try await read(into: &buffer, at: ..<Int(length))
        buffer.removeLast(Int(Int64(buffer.count) - bytesRead))
        return buffer
    }

}



extension AsyncSequentialReadFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    @_lifetime(buffer: copy buffer)
    public func read(into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64 {
        return try await withSyncHandleAdapterInExecutor { adapter throws(PlatformError) in
            try adapter.read(into: &buffer)
        }
        .getThrowingPlatformError(operation: .readHandle(originalPath: path))
    }

}
