//
//  WriteFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



public protocol PersistentFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    func synchronize() throws(PlatformError)
}



extension PersistentFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {
    public func synchronize() throws(PlatformError) {
        return try catchLowLevelError(operation: .syncHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.withUnsafeSystemHandle { handle throws(LowLevelError) in
                try handle.fsync()
            }
        }
    }
}



public protocol ResizableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {
    func resize(to size: Int64) throws(PlatformError)
}



extension ResizableFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    public func resize(to size: Int64) throws(PlatformError) {
        return try catchLowLevelError(operation: .resizeHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.withUnsafeSystemHandle { handle throws(LowLevelError) in
                try handle.truncate(to: size)
            }
        }
    }

}



public protocol PositionalWriteFileHandleProtocol: ~Copyable, ~Escapable, ResizableFileHandleProtocol {

    @discardableResult
    func write(_ buffer: RawSpan, toOffset offset: Int64) throws(PlatformError) -> Int64

}



extension PositionalWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @discardableResult
    public func write(_ data: ByteBuffer, toOffset offset: Int64) throws(PlatformError) -> Int64 {
        return try write(data.bytes, toOffset: offset)
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
        return try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.withUnsafeSystemHandle { handle throws(LowLevelError) in
                try handle.pwrite(contentsOf: buffer, to: offset)
            }
        }
    }

}



public protocol SequentialWriteFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    @discardableResult
    func write(_ buffer: RawSpan) throws(PlatformError) -> Int64

}



extension SequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @discardableResult
    public func write(_ data: ByteBuffer) throws(PlatformError) -> Int64 {
        return try write(data.bytes)
    }

}



extension SequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    @discardableResult
    public func write(_ buffer: RawSpan) throws(PlatformError) -> Int64 {
        return try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.withUnsafeSystemHandle { handle throws(LowLevelError) in
                try handle.write(contentsOf: buffer)
            }
        }
    }

}



public protocol AppendableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    @discardableResult
    func append(_ buffer: RawSpan) throws(PlatformError) -> Int64

}



extension AppendableFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @discardableResult
    public func append(_ data: ByteBuffer) throws(PlatformError) -> Int64 {
        return try append(data.bytes)
    }

}
