//
//  AsyncAppendHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


public struct AsyncAppendHandle
: ~Copyable, @unchecked Sendable
, AsyncAppendableFileHandleProtocol, AsyncPersistentFileHandleProtocol
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
            try AppendHandle(forFileAt: path, options: options, creationPermissions: creationPermissions).takeUnsafeSystemHandle()
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
            try AppendHandle(forFileAt: path, options: options, creationPermissions: creationPermissions).takeUnsafeSystemHandle()
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


    @concurrent
    @discardableResult
    public func append(_ buffer: RawSpan) async throws(PlatformError) -> Int64 {
        let path = self.path
        return try await withUnsafeSystemHandleInExecutor(operation: .writeHandle(originalPath: path)) { (sysHandle) throws(LowLevelError) in
            try buffer.withUnsafeBytes { buffer throws(LowLevelError) in
                #if canImport(WinSDK)
                try sysHandle.pwrite(contentsOf: buffer, to: -1)
                #else
                try sysHandle.write(contentsOf: buffer)
                #endif
            }
        }
    }

}
