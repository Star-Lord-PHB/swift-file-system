//
//  AsyncPositionalHandleAccessor.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/9/2.
//

import FileSystemCore
import struct SwiftFileSystem.UnsafeHandleContextView
import struct SwiftFileSystem.UnsafeHandleContext



struct AsyncPositionalHandleAccessor
: ~Escapable
, AsyncMutatingSequentialReadFileHandleProtocol
, AsyncMutatingSequentialWriteFileHandleProtocol, AsyncMutatingSeekableFileHandleProtocol
, AsyncResizableFileHandleProtocol, AsyncPersistentFileHandleProtocol
, AutoSynthesisAsyncFileHandleProtocol {

    let context: UnsafeHandleContextView
    let executor: AsyncFileSystemExecutor
    let path: FilePath

    private(set) var currentOffset: Int64 = 0


    @_lifetime(borrow unsafeHandleContext)
    init(unsafeHandleContext: borrowing UnsafeHandleContext, path: FilePath, executor: AsyncFileSystemExecutor) {
        self.context = unsafeHandleContext.view
        self.executor = executor
        self.path = path
    }


    var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(copy self) get { context }
    }


    @concurrent
    @discardableResult
    @_lifetime(self: copy self)
    mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) async throws(PlatformError) -> Int64 {
        let newOffset: Int64
        switch whence {
        case .current:
            newOffset = try catchLowLevelError(operation: .seekHandle(originalPath: path)) { () throws(LowLevelError) in
                try UnsafeHandleContextView.trySeek(from: self.currentOffset, by: offset)
            }
        case .beginning:
            newOffset = try catchLowLevelError(operation: .seekHandle(originalPath: path)) { () throws(LowLevelError) in
                try UnsafeHandleContextView.trySeek(from: 0, by: offset)
            }
        case .end:
            let fileSize = try await self.fileInfo().size
            newOffset = try catchLowLevelError(operation: .seekHandle(originalPath: path)) { () throws(LowLevelError) in
                try UnsafeHandleContextView.trySeek(from: Int64(fileSize), by: offset)
            }
        }
        self.currentOffset = newOffset
        return newOffset
    }


    @concurrent
    @_lifetime(self: copy self)
    @_lifetime(buffer: copy buffer)
    mutating func read(into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64 {
        let currentOffset = self.currentOffset
        let bytesRead = try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.read(fromOffset: currentOffset, into: &buffer)
        }
        .getThrowingPlatformError(operation: .readHandle(originalPath: path))
        self.currentOffset = currentOffset + bytesRead
        return bytesRead
    }


    @concurrent
    @discardableResult
    @_lifetime(self: copy self)
    mutating func write(_ bytes: RawSpan) async throws(PlatformError) -> Int64 {
        let currentOffset = self.currentOffset
        let bytesWritten = try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.write(bytes, toOffset: currentOffset)
        }
        .getThrowingPlatformError(operation: .writeHandle(originalPath: path))
        self.currentOffset = currentOffset + bytesWritten
        return bytesWritten
    }

}
