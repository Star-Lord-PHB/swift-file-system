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

    fileprivate let context: UnsafeHandleContext
    public let executor: AsyncFileSystemExecutor
    public let path: FilePath


    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: FilePermissions? = nil,
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.context = try await executor.runCancellable { () throws(PlatformError) in
            try AppendHandle(forFileAt: path, options: options, creationPermissions: creationPermissions)
        }
        .getThrowingPlatformError(operation: .open(path))
        .takeUnsafeHandleContext()
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
        self.context = try await executor.runCancellable { () throws(PlatformError) in
            try AppendHandle(forFileAt: path, options: options, creationPermissions: creationPermissions)
        }
        .getThrowingPlatformError(operation: .open(path))
        .takeUnsafeHandleContext()
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


    @concurrent
    @discardableResult
    public func append(_ buffer: RawSpan) async throws(PlatformError) -> Int64 {
        return try await withUnsafeSystemHandleInExecutor { (sysHandle) throws(LowLevelError) in
            try buffer.withUnsafeBytes { buffer throws(LowLevelError) in
                #if canImport(WinSDK)
                try sysHandle.pwrite(contentsOf: buffer, to: -1)
                #else
                try sysHandle.write(contentsOf: buffer)
                #endif
            }
        }
        .getThrowingPlatformError(operation: .writeHandle(originalPath: path))
    }

}
