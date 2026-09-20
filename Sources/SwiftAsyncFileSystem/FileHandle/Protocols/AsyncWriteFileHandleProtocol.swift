//
//  AsyncWriteFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


public protocol AsyncPersistentFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

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



public protocol AsyncResizableFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

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



public protocol AsyncPositionalWriteFileHandleProtocol: ~Copyable, ~Escapable, AsyncResizableFileHandleProtocol {

    @concurrent
    @discardableResult
    func write(_ buffer: RawSpan, toOffset offset: Int64) async throws(PlatformError) -> Int64

}



extension AsyncPositionalWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    @discardableResult
    public func write(_ data: ByteBuffer, toOffset offset: Int64) async throws(PlatformError) -> Int64 {
        return try await write(data.bytes, toOffset: offset)
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



public protocol AsyncSequentialWriteFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    @concurrent
    @discardableResult
    func write(_ buffer: RawSpan) async throws(PlatformError) -> Int64

}



extension AsyncSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    @discardableResult
    public func write(_ data: ByteBuffer) async throws(PlatformError) -> Int64 {
        return try await write(data.bytes)
    }

}



extension AsyncSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    @discardableResult
    public func write(_ buffer: RawSpan) async throws(PlatformError) -> Int64 {
        return try await withSyncHandleAdapterInExecutor { adapter throws(PlatformError) in
            try adapter.write(buffer)
        }
        .getThrowingPlatformError(operation: .writeHandle(originalPath: path))
    }

}



public protocol AsyncAppendableFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    @concurrent
    @discardableResult
    func append(_ buffer: RawSpan) async throws(PlatformError) -> Int64

}



// The span primitive has no shared default implementation on purpose: append is not a
// dedicated write API on POSIX — it is plain write against a descriptor that was opened
// with O_APPEND, so only the concrete append handle (which owns that open mode) can
// implement it honestly.
extension AsyncAppendableFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    @discardableResult
    public func append(_ data: ByteBuffer) async throws(PlatformError) -> Int64 {
        return try await append(data.bytes)
    }

}
