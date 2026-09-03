//
//  AsyncWriteFileHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


public struct AsyncWriteFileHandle
: ~Copyable, @unchecked Sendable
, AsyncPositionalWriteFileHandleProtocol, AsyncPersistentFileHandleProtocol
, AutoSynthesisAsyncFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle
    public let executor: AsyncFileSystemExecutor
    public let path: FilePath


    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: FilePermissions? = nil,
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.handle = try await executor.runCancellable { () throws(PlatformError) in
            try WriteFileHandle(forFileAt: path, options: options, creationPermissions: creationPermissions).takeUnsafeSystemHandle()
        }.getThrowingPlatformError(operation: .open(path))
        self.executor = executor
        self.path = path
    }


    #if canImport(WinSDK)
    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: WindowsSecurityDescriptorView,
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.handle = try await executor.runCancellable { () throws(PlatformError) in
            try WriteFileHandle(forFileAt: path, options: options, creationPermissions: creationPermissions).takeUnsafeSystemHandle()
        }.getThrowingPlatformError(operation: .open(path))
        self.executor = executor
        self.path = path
    }


    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: borrowing WindowsAbsoluteSecurityDescriptor,
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        try await self.init(forFileAt: path, options: options, creationPermissions: creationPermissions.view, executor: executor)
    }


    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: borrowing WindowsSelfRelativeSecurityDescriptor,
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        try await self.init(forFileAt: path, options: options, creationPermissions: creationPermissions.view, executor: executor)
    }
    #endif


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



extension AsyncWriteFileHandle {

    @_lifetime(borrow self)
    public func sequentialWriter() -> SequentialWriter {
        .init(writeHandle: self)
    }


    public struct SequentialWriter
    : ~Escapable
    , AsyncMutatingSequentialWriteFileHandleProtocol, AsyncMutatingSeekableFileHandleProtocol
    , AsyncResizableFileHandleProtocol, AsyncPersistentFileHandleProtocol
    , AutoSynthesisAsyncFileHandleProtocol {

        private var accessor: AsyncPositionalHandleAccessor

        public var executor: AsyncFileSystemExecutor { accessor.executor }
        public var path: FilePath { accessor.path }

        public var currentOffset: Int64 { accessor.currentOffset }


        @_lifetime(borrow writeHandle)
        init(writeHandle: borrowing AsyncWriteFileHandle) {
            self.accessor = .init(handle: writeHandle.handle, path: writeHandle.path, executor: writeHandle.executor)
        }


        @concurrent
        public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
            _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> sending R
        ) async throws(E) -> sending R {
            try await accessor.withUnsafeSystemHandle(operation)
        }


        @concurrent
        @discardableResult
        @_lifetime(self: copy self)
        public mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) async throws(PlatformError) -> Int64 {
            try await accessor.seek(to: offset, relativeTo: whence)
        }


        @concurrent
        @discardableResult
        @_lifetime(self: copy self)
        public mutating func write(_ bytes: RawSpan) async throws(PlatformError) -> Int64 {
            try await accessor.write(bytes)
        }


    }

}
