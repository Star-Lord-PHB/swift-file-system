//
//  AsyncWriteFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// A protocol for file handles that support synchronizing with the underlying device.
public protocol AsyncPersistentFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    /// Synchronizes the file handle with the underlying device.
    @concurrent
    func synchronize() async throws(PlatformError)

}



extension AsyncPersistentFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    public func synchronize() async throws(PlatformError) {
        return try await withSyncHandleAdapterInExecutor { adapter throws(PlatformError) in
            try adapter.synchronize()
        }
        .getThrowingPlatformError(operation: .syncHandle(originalPath: path))
    }

}



/// A protocol for file handles that support resizing.
public protocol AsyncResizableFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    /// Resizes the file to the specified size.
    @concurrent
    func resize(to size: Int64) async throws(PlatformError)

}



extension AsyncResizableFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    public func resize(to size: Int64) async throws(PlatformError) {
        return try await withSyncHandleAdapterInExecutor { adapter throws(PlatformError) in
            try adapter.resize(to: size)
        }
        .getThrowingPlatformError(operation: .resizeHandle(originalPath: path))
    }

}



/// A protocol for file handles that support positional writing operations.
public protocol AsyncPositionalWriteFileHandleProtocol: ~Copyable, ~Escapable, AsyncResizableFileHandleProtocol {

    /// Writes the provided bytes into the file handle at the specified offset.
    /// - Parameters:
    ///   - buffer: The bytes to write into the file handle.
    ///   - offset: The offset relative to the beginning of the file to write to.
    /// - Returns: The number of bytes actually written into the file handle.
    @concurrent
    @discardableResult
    func write(_ buffer: RawSpan, toOffset offset: Int64) async throws(PlatformError) -> Int64

}



extension AsyncPositionalWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Writes the provided bytes into the file handle at the specified offset.
    /// - Parameters:
    ///   - buffer: The bytes to write into the file handle.
    ///   - offset: The offset relative to the beginning of the file to write to.
    /// - Returns: The number of bytes actually written into the file handle.
    @concurrent
    @discardableResult
    public func write(_ buffer: ByteBuffer, toOffset offset: Int64) async throws(PlatformError) -> Int64 {
        return try await write(buffer.bytes, toOffset: offset)
    }

}



extension AsyncPositionalWriteFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    @discardableResult
    public func write(_ buffer: RawSpan, toOffset offset: Int64) async throws(PlatformError) -> Int64 {
        return try await withSyncHandleAdapterInExecutor { adapter throws(PlatformError) in
            try adapter.write(buffer, toOffset: offset)
        }
        .getThrowingPlatformError(operation: .writeHandle(originalPath: path))
    }

}



/// A protocol for file handles that support sequential writing.
public protocol AsyncSequentialWriteFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    /// Writes the provided bytes into the file handle at the current position of the file pointer.
    /// - Parameter bytes: The bytes to write into the file handle.
    /// - Returns: The number of bytes actually written into the file handle.
    @concurrent
    @discardableResult
    func write(_ bytes: RawSpan) async throws(PlatformError) -> Int64

}



extension AsyncSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Writes the provided bytes into the file handle at the current position of the file pointer.
    /// - Parameter bytes: The bytes to write into the file handle.
    /// - Returns: The number of bytes actually written into the file handle.
    @concurrent
    @discardableResult
    public func write(_ bytes: ByteBuffer) async throws(PlatformError) -> Int64 {
        return try await write(bytes.bytes)
    }

}



extension AsyncSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    @discardableResult
    public func write(_ bytes: RawSpan) async throws(PlatformError) -> Int64 {
        return try await withSyncHandleAdapterInExecutor { adapter throws(PlatformError) in
            try adapter.write(bytes)
        }
        .getThrowingPlatformError(operation: .writeHandle(originalPath: path))
    }

}



/// A protocol for file handles that support atomically appending data to the end of the file.
public protocol AsyncAppendableFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    /// Appends the provided bytes to the end of the file handle atomically.
    /// - Parameter bytes: The bytes to append to the end of the file handle.
    /// - Returns: The number of bytes actually appended to the file handle.
    @concurrent
    @discardableResult
    func append(_ bytes: RawSpan) async throws(PlatformError) -> Int64

}



extension AsyncAppendableFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Appends the provided bytes to the end of the file handle atomically.
    /// - Parameter bytes: The bytes to append to the end of the file handle.
    /// - Returns: The number of bytes actually appended to the file handle.
    @concurrent
    @discardableResult
    public func append(_ bytes: ByteBuffer) async throws(PlatformError) -> Int64 {
        return try await append(bytes.bytes)
    }

}
