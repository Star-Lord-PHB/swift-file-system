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

    fileprivate let context: UnsafeHandleContext
    public let path: FilePath
    public let executor: AsyncFileSystemExecutor


    @concurrent
    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForStreaming = .init(),
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.context = try await executor.runCancellable { () throws(PlatformError) in
            try StreamingWriteHandle(forFileAt: path, options: options)
        }
        .getThrowingPlatformError(operation: .open(path))
        .takeUnsafeHandleContext()
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
        var context = Optional.some(self.context)
        return try await executor.run { () throws(PlatformError) in
            try catchLowLevelError(operation: .closeHandle(originalPath: path)) { () throws(LowLevelError) in
                let handle = context.take()!
                try handle.close()
            }
        }
    }


    public var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get { context.view }
    }

}
