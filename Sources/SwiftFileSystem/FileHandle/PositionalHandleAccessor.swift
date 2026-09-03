//
//  PositionalHandleAccessor.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/9/2.
//

import FileSystemCore
import struct SystemPackage.FilePath



struct PositionalHandleAccessor
: ~Escapable
, MutatingSequentialReadFileHandleProtocol
, MutatingSequentialWriteFileHandleProtocol, MutatingSeekableFileHandleProtocol
, ResizableFileHandleProtocol, PersistentFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    let handle: UnsafeUnownedSystemHandle
    let path: FilePath

    private(set) var currentOffset: Int64 = 0


    @_lifetime(borrow handle)
    init(handle: borrowing UnsafeSystemHandle, path: FilePath) {
        self.handle = handle.unownedHandle()
        self.path = path
    }


    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try self.handle.unsafeTemporaryConvertingToOwning { handle throws(E) in
            try body(handle)
        }
    }


    @discardableResult
    @_lifetime(self: copy self)
    mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) throws(PlatformError) -> Int64 {
        let newOffset = switch whence {
        case .current:
            try trySeek(from: self.currentOffset, by: offset, operation: .seekHandle(originalPath: path))
        case .beginning:
            try trySeek(from: 0, by: offset, operation: .seekHandle(originalPath: path))
        case .end:
            try trySeek(from: .init(fileInfo().size), by: offset, operation: .seekHandle(originalPath: path))
        }
        self.currentOffset = newOffset
        return newOffset
    }


    @_lifetime(self: copy self)
    @_lifetime(buffer: copy buffer)
    mutating func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64 {
        try catchLowLevelError(operation: .readHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.handle.unsafeTemporaryConvertingToOwning { handle throws(LowLevelError) in
                do throws(LowLevelError) {
                    let currentOffset = self.currentOffset
                    let bytesRead = try handle.pread(into: &buffer, from: currentOffset)
                    self.currentOffset = currentOffset + bytesRead
                    return bytesRead
                } catch {
                    #if canImport(WinSDK)
                    if error.systemCode == .handleEOF { return 0 }
                    #endif
                    throw error
                }
            }
        }
    }


    @discardableResult
    @_lifetime(self: copy self)
    mutating func write(_ buffer: RawSpan) throws(PlatformError) -> Int64 {
        try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.handle.unsafeTemporaryConvertingToOwning { handle throws(LowLevelError) in
                let currentOffset = self.currentOffset
                let bytesWritten = try handle.pwrite(contentsOf: buffer, to: currentOffset)
                self.currentOffset = currentOffset + bytesWritten
                return bytesWritten
            }
        }
    }

}
