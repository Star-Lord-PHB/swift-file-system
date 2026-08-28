//
//  ReadFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



public protocol PositionalReadFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    @_lifetime(buffer: copy buffer)
    func read(fromOffset offset: Int64, into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64

}



extension PositionalReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    public func read(fromOffset offset: Int64, into buffer: consuming MutableRawSpan) throws(PlatformError) -> Int64 {
        return try read(fromOffset: offset, into: &buffer)
    }


    public func read(
        fromOffset offset: Int64,
        into buffer: inout ByteBuffer,
        at bufferRange: some RangeExpression<Int> = 0...
    ) throws(PlatformError) -> Int64 {
        return try read(fromOffset: offset, into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }


    public func read(fromOffset offset: Int64, length: Int64) throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        let bytesRead = try read(fromOffset: offset, into: &buffer, at: ..<Int(length))
        buffer.removeLast(Int(Int64(buffer.count) - bytesRead))
        return buffer
    }

}



extension PositionalReadFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    @_lifetime(buffer: copy buffer)
    public func read(fromOffset offset: Int64, into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64 {
        #if canImport(WinSDK)
        // A negative OVERLAPPED offset would be read as a position near the end of the unsigned
        // 64-bit range; reject it up front like POSIX pread reports EINVAL.
        guard offset >= 0 else {
            throw .init(lowLevelError: .init(kind: .invalidInput), operation: .readHandle(originalPath: path))
        }
        #endif
        return try catchLowLevelError(operation: .readHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.withUnsafeSystemHandle { (handle) throws(LowLevelError) in
                do throws(LowLevelError) {
                    return try handle.pread(into: &buffer, from: offset)
                } catch {
                    #if canImport(WinSDK)
                    if error.systemCode == .handleEOF { return 0 }
                    #endif
                    throw error
                }
            }
        }
    }

}



public protocol SequentialReadFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    @_lifetime(buffer: copy buffer)
    func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64

}



extension SequentialReadFileHandleProtocol where Self: ~Copyable & ~Escapable {

    public func read(into buffer: consuming MutableRawSpan) throws(PlatformError) -> Int64 {
        return try read(into: &buffer)
    }


    public func read(into buffer: inout ByteBuffer, at bufferRange: some RangeExpression<Int> = 0...) throws(PlatformError) -> Int64 {
        return try read(into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }


    public func read(length: Int64) throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        let bytesRead = try read(into: &buffer, at: ..<Int(length))
        buffer.removeLast(Int(Int64(buffer.count) - bytesRead))
        return buffer
    }

}



extension SequentialReadFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    @_lifetime(buffer: copy buffer)
    public func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64 {
        return try catchLowLevelError(operation: .readHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.withUnsafeSystemHandle { handle throws(LowLevelError) in
                do throws(LowLevelError) {
                    return try handle.read(into: &buffer)
                } catch {
                    // A Windows pipe whose peer closed (ERROR_BROKEN_PIPE) or disconnected
                    // (ERROR_PIPE_NOT_CONNECTED) fails the read where POSIX returns zero
                    // bytes; the stream semantics align on end-of-file.
                    #if canImport(WinSDK)
                    if error.systemCode == .brokenPipe || error.systemCode == .pipeNotConnected {
                        return 0
                    }
                    #endif
                    throw error
                }
            }
        }
    }

}
