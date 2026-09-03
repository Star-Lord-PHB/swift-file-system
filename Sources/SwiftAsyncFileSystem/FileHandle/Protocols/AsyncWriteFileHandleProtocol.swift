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
        return try await withSyncHandleViewInExecutor(operation: .syncHandle(originalPath: path)) { (view) throws(PlatformError) in
            try view.synchronize()
        }
    }

}



public protocol AsyncResizableFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    @concurrent
    func resize(to size: Int64) async throws(PlatformError)

}



extension AsyncResizableFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    public func resize(to size: Int64) async throws(PlatformError) {
        return try await withSyncHandleViewInExecutor(operation: .resizeHandle(originalPath: path)) { (view) throws(PlatformError) in
            try view.resize(to: size)
        }
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
        return try await withSyncHandleViewInExecutor(operation: .writeHandle(originalPath: path)) { (view) throws(PlatformError) in
            try view.write(buffer, toOffset: offset)
        }
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
        return try await withSyncHandleViewInExecutor(operation: .writeHandle(originalPath: path)) { (view) throws(PlatformError) in
            try view.write(buffer)
        }
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
