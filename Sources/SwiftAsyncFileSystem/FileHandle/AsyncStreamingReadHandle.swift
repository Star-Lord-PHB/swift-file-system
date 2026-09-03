//
//  AsyncStreamingReadHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// Async counterpart of `StreamingReadHandle`. Like the synchronous type it is not
/// Sendable: a blocking byte stream has shared cursor state, so a handle belongs to one
/// task at a time. A pending read occupies an executor worker thread until bytes arrive.
public struct AsyncStreamingReadHandle
: ~Copyable
, AsyncSequentialReadFileHandleProtocol, AutoSynthesisAsyncFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle
    public let path: FilePath
    public let executor: AsyncFileSystemExecutor


    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForStreaming = .init(),
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.handle = try await executor.runCancellable { () throws(PlatformError) in
            try StreamingReadHandle(forFileAt: path, options: options).takeUnsafeSystemHandle()
        }.getThrowingPlatformError(operation: .open(path))
        self.executor = executor
        self.path = path
    }


    /// Closes the handle on the executor. Unlike the other operations, closing never
    /// observes task cancellation: the handle is consumed either way, so a cancelled close
    /// could not be retried and would only move the actual closing to the deinit on the
    /// calling thread.
    @concurrent
    public consuming func close() async throws(PlatformError) {
        let executor = self.executor
        let path = self.path
        var handle = Optional.some(self.handle)
        return try await executor.run { () throws(PlatformError) in
            try catchLowLevelError(operation: .closeHandle(originalPath: path)) { () throws(LowLevelError) in
                let handle = handle.take()!
                try handle.close()
            }
        }
    }


    @concurrent
    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> sending R
    ) async throws(E) -> sending R {
        return try await operation(handle)
    }

}
