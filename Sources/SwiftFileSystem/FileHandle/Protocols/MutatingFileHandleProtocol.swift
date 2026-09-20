//
//  MutatingFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import FileSystemCore
import struct SystemPackage.FilePath



public protocol MutatingSeekableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    @discardableResult
    @_lifetime(self: copy self)
    mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64
    var currentOffset: Int64 { get throws(PlatformError) }
}



public protocol MutatingSequentialReadFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    @_lifetime(self: copy self)
    @_lifetime(buffer: copy buffer)
    mutating func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64
}



extension MutatingSequentialReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @_lifetime(self: copy self)
    public mutating func read(into buffer: consuming MutableRawSpan) throws(PlatformError) -> Int64 {
        return try self.read(into: &buffer)
    }

    @_lifetime(self: copy self)
    public mutating func read(into buffer: inout ByteBuffer, at bufferRange: some RangeExpression<Int> = 0...) throws(PlatformError) -> Int64 {
        return try self.read(into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }

    @_lifetime(self: copy self)
    public mutating func read(length: Int64) throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        let bytesRead = try read(into: &buffer, at: ..<Int(length))
        buffer.removeLast(Int(Int64(buffer.count) - bytesRead))
        return buffer
    }

}



public protocol MutatingSequentialWriteFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    @discardableResult
    @_lifetime(self: copy self)
    mutating func write(_ bytes: RawSpan) throws(PlatformError) -> Int64
}



extension MutatingSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {
    @discardableResult
    @_lifetime(self: copy self)
    public mutating func write(_ bytes: ByteBuffer) throws(PlatformError) -> Int64 {
        return try self.write(bytes.bytes)
    }
}
