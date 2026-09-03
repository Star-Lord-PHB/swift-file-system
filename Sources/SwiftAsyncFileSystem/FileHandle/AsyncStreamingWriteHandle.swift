//
//  AsyncStreamingWriteHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// Async counterpart of `StreamingWriteHandle`. Like the synchronous type it is not
/// Sendable: a blocking byte stream has shared cursor state, so a handle belongs to one
/// task at a time. A pending write occupies an executor worker thread until it completes.
public struct AsyncStreamingWriteHandle
: ~Copyable
, AsyncSequentialWriteFileHandleProtocol, AutoSynthesisAsyncFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle
    public let path: FilePath
    public let executor: AsyncFileSystemExecutor


    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForStreaming = .init(),
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.handle = try await executor.runCancellable { () throws(PlatformError) in
            try StreamingWriteHandle(forFileAt: path, options: options).takeUnsafeSystemHandle()
        }.getThrowingPlatformError(operation: .open(path))
        self.executor = executor
        self.path = path
    }


    @concurrent
    public consuming func close() async throws(PlatformError) {
        let executor = self.executor
        let path = self.path
        var handle = Optional.some(self.handle)
        return try await executor.runCancellable { () throws(LowLevelError) in
            let handle = handle.take()!
            try handle.close()
        }.getThrowingPlatformError(operation: .closeHandle(originalPath: path))
    }


    @concurrent
    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> sending R
    ) async throws(E) -> sending R {
        return try await operation(handle)
    }

}
