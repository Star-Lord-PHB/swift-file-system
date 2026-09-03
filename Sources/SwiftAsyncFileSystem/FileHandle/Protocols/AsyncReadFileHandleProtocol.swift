//
//  AsyncReadFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


public protocol AsyncPositionalReadFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    @concurrent
    @_lifetime(buffer: copy buffer)
    func read(fromOffset offset: Int64, into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64

}



extension AsyncPositionalReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    public func read(fromOffset offset: Int64, into buffer: consuming MutableRawSpan) async throws(PlatformError) -> Int64 {
        return try await read(fromOffset: offset, into: &buffer)
    }


    @concurrent
    public func read(
        fromOffset offset: Int64,
        into buffer: inout ByteBuffer,
        at bufferRange: some RangeExpression<Int> = 0...
    ) async throws(PlatformError) -> Int64 {
        return try await read(fromOffset: offset, into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }


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
        return try await withSyncHandleViewInExecutor(operation: .readHandle(originalPath: path)) { (view) throws(PlatformError) in
            try view.read(fromOffset: offset, into: &buffer)
        }
    }

}



public protocol AsyncSequentialReadFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    @concurrent
    @_lifetime(buffer: copy buffer)
    func read(into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64

}



extension AsyncSequentialReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    public func read(into buffer: consuming MutableRawSpan) async throws(PlatformError) -> Int64 {
        return try await read(into: &buffer)
    }


    @concurrent
    public func read(into buffer: inout ByteBuffer, at bufferRange: some RangeExpression<Int> = 0...) async throws(PlatformError) -> Int64 {
        return try await read(into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }


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
        return try await withSyncHandleViewInExecutor(operation: .readHandle(originalPath: path)) { (view) throws(PlatformError) in
            try view.read(into: &buffer)
        }
    }

}
