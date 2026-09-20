//
//  AsyncReadFileHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


public struct AsyncReadFileHandle
: ~Copyable, @unchecked Sendable
, AsyncPositionalReadFileHandleProtocol, AutoSynthesisAsyncFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let executor: AsyncFileSystemExecutor
    public let path: FilePath


    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForReading = .init(),
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.context = try await executor.runCancellable { () throws(PlatformError) in
            try ReadFileHandle(forFileAt: path, options: options)
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



extension AsyncReadFileHandle {

    @_lifetime(borrow self)
    public func sequentialReader() -> SequentialReader {
        .init(readHandle: self)
    }


    public struct SequentialReader
    : ~Escapable
    , AsyncMutatingSequentialReadFileHandleProtocol, AsyncMutatingSeekableFileHandleProtocol
    , AutoSynthesisAsyncFileHandleProtocol {

        private var accessor: AsyncPositionalHandleAccessor

        public var executor: AsyncFileSystemExecutor { accessor.executor }
        public var path: FilePath { accessor.path }

        public var currentOffset: Int64 { accessor.currentOffset }


        @_lifetime(borrow readHandle)
        init(readHandle: borrowing AsyncReadFileHandle) {
            self.accessor = .init(
                unsafeHandleContext: readHandle.context, 
                path: readHandle.path, 
                executor: readHandle.executor
            )
        }


        public var unsafeHandleContext: UnsafeHandleContextView {
            @_lifetime(copy self) get { accessor.unsafeHandleContext }
        }


        @concurrent
        @discardableResult
        @_lifetime(self: copy self)
        public mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) async throws(PlatformError) -> Int64 {
            try await accessor.seek(to: offset, relativeTo: whence)
        }


        @concurrent
        @_lifetime(self: copy self)
        @_lifetime(buffer: copy buffer)
        public mutating func read(into buffer: inout MutableRawSpan) async throws(PlatformError) -> Int64 {
            try await accessor.read(into: &buffer)
        }

    }

}
