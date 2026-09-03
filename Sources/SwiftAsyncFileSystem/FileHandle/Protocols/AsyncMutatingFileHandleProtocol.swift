//
//  AsyncMutatingFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/9/2.
//

import SwiftFileSystem


public protocol AsyncMutatingSeekableFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    @concurrent
    @discardableResult
    @_lifetime(self: copy self)
    mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) async throws(PlatformError) -> Int64

    var currentOffset: Int64 { get throws(PlatformError) }

}



extension AsyncMutatingSeekableFileHandleProtocol where Self: ~Copyable & ~Escapable {

    func trySeek(from offset: Int64, by amount: Int64, operation: @autoclosure () -> PlatformError.Operation) throws(PlatformError) -> Int64 {
        let (result, overflow) = offset.addingReportingOverflow(amount)
        if overflow {
            throw .init(lowLevelError: .init(kind: .arithmeticOverflow), operation: operation())
        } else if result < 0 {
            throw .init(lowLevelError: .init(kind: .invalidInput), operation: operation())
        }
        return result
    }

}



public protocol AsyncMutatingSequentialReadFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    @concurrent
    @_lifetime(self: copy self)
    @_lifetime(buffer: copy buffer)
    mutating func read(into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64

}



extension AsyncMutatingSequentialReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    @_lifetime(self: copy self)
    public mutating func read(into buffer: consuming MutableRawSpan) async throws(PlatformError) -> Int64 {
        return try await self.read(into: &buffer)
    }


    @concurrent
    @_lifetime(self: copy self)
    public mutating func read(into buffer: inout ByteBuffer, at bufferRange: some RangeExpression<Int> = 0...) async throws(PlatformError) -> Int64 {
        return try await self.read(into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }


    @concurrent
    @_lifetime(self: copy self)
    public mutating func read(length: Int64) async throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        let bytesRead = try await read(into: &buffer, at: ..<Int(length))
        buffer.removeLast(Int(Int64(buffer.count) - bytesRead))
        return buffer
    }

}



public protocol AsyncMutatingSequentialWriteFileHandleProtocol: ~Copyable, ~Escapable, AsyncFileHandleProtocol {

    @concurrent
    @discardableResult
    @_lifetime(self: copy self)
    mutating func write(_ bytes: RawSpan) async throws(PlatformError) -> Int64

}



extension AsyncMutatingSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    @discardableResult
    @_lifetime(self: copy self)
    public mutating func write(_ bytes: ByteBuffer) async throws(PlatformError) -> Int64 {
        return try await self.write(bytes.bytes)
    }

}
