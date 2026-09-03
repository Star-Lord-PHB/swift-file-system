//
//  AsyncPositionalHandleAccessor.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/9/2.
//

import FileSystemCore


struct AsyncPositionalHandleAccessor
: ~Escapable
, AsyncMutatingSequentialReadFileHandleProtocol
, AsyncMutatingSequentialWriteFileHandleProtocol, AsyncMutatingSeekableFileHandleProtocol
, AsyncResizableFileHandleProtocol, AsyncPersistentFileHandleProtocol
, AutoSynthesisAsyncFileHandleProtocol {

    let handle: UnsafeUnownedSystemHandle
    let executor: AsyncFileSystemExecutor
    let path: FilePath

    private(set) var currentOffset: Int64 = 0


    @_lifetime(borrow handle)
    init(handle: borrowing UnsafeSystemHandle, path: FilePath, executor: AsyncFileSystemExecutor) {
        self.handle = handle.unownedHandle()
        self.executor = executor
        self.path = path
    }


    @concurrent
    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> sending R
    ) async throws(E) -> sending R {
        try await self.handle.unsafeTemporaryConvertingToOwning { handle async throws(E) in
            try await operation(handle)
        }
    }


    @concurrent
    @discardableResult
    @_lifetime(self: copy self)
    mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) async throws(PlatformError) -> Int64 {
        let newOffset: Int64
        switch whence {
        case .current:
            newOffset = try trySeek(from: self.currentOffset, by: offset, operation: .seekHandle(originalPath: path))
        case .beginning:
            newOffset = try trySeek(from: 0, by: offset, operation: .seekHandle(originalPath: path))
        case .end:
            newOffset = try await trySeek(from: Int64(fileInfo().size), by: offset, operation: .seekHandle(originalPath: path))
        }
        self.currentOffset = newOffset
        return newOffset
    }


    @concurrent
    @_lifetime(self: copy self)
    @_lifetime(buffer: copy buffer)
    mutating func read(into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64 {
        let currentOffset = self.currentOffset
        let bytesRead = try await withSyncHandleViewInExecutor(operation: .readHandle(originalPath: path)) { (view) throws(PlatformError) in
            try view.read(fromOffset: currentOffset, into: &buffer)
        }
        self.currentOffset = currentOffset + bytesRead
        return bytesRead
    }


    @concurrent
    @discardableResult
    @_lifetime(self: copy self)
    mutating func write(_ bytes: RawSpan) async throws(PlatformError) -> Int64 {
        let currentOffset = self.currentOffset
        let bytesWritten = try await withSyncHandleViewInExecutor(operation: .writeHandle(originalPath: path)) { (view) throws(PlatformError) in
            try view.write(bytes, toOffset: currentOffset)
        }
        self.currentOffset = currentOffset + bytesWritten
        return bytesWritten
    }

}
