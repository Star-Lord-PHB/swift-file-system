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

    let context: UnsafeHandleContextView
    let path: FilePath

    private(set) var currentOffset: Int64 = 0


    @_lifetime(borrow unsafeHandleContext)
    init(unsafeHandleContext: borrowing UnsafeHandleContext, path: FilePath) {
        self.context = unsafeHandleContext.view
        self.path = path
    }


    var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(copy self) get { context }
    }


    @discardableResult
    @_lifetime(self: copy self)
    mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) throws(PlatformError) -> Int64 {
        let newOffset = try catchLowLevelError(operation: .seekHandle(originalPath: path)) { () throws(LowLevelError) in
            switch whence {
            case .current:
                try UnsafeHandleContextView.trySeek(from: self.currentOffset, by: offset)
            case .beginning:
                try UnsafeHandleContextView.trySeek(from: 0, by: offset)
            case .end:
                try context.withUnsafeSystemHandle { handle throws(LowLevelError) in
                    try UnsafeHandleContextView.trySeek(from: .init(handle.fileInfo().size), by: offset)
                }
            }
        }
        self.currentOffset = newOffset
        return newOffset
    }


    @_lifetime(self: copy self)
    @_lifetime(buffer: copy buffer)
    mutating func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64 {
        try catchLowLevelError(operation: .readHandle(originalPath: path)) { () throws(LowLevelError) in
            do throws(LowLevelError) {
                let currentOffset = self.currentOffset
                let bytesRead = try context.withUnsafeSystemHandle { (handle) throws(LowLevelError) in
                    try handle.pread(into: &buffer, from: currentOffset)
                }
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


    @discardableResult
    @_lifetime(self: copy self)
    mutating func write(_ buffer: RawSpan) throws(PlatformError) -> Int64 {
        try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
            let currentOffset = self.currentOffset
            let bytesWritten = try context.withUnsafeSystemHandle { (handle) throws(LowLevelError) in
                try handle.pwrite(contentsOf: buffer, to: currentOffset)
            }
            self.currentOffset = currentOffset + bytesWritten
            return bytesWritten
        }
    }

}
