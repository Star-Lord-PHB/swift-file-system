//
//  AsyncAppendHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// A file handle for appending data to the end of a file atomically.
public struct AsyncAppendHandle
: ~Copyable, @unchecked Sendable
, AsyncAppendableFileHandleProtocol, AsyncPersistentFileHandleProtocol
, AutoSynthesisAsyncFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let executor: AsyncFileSystemExecutor
    public let path: FilePath


    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - creationPermissions: The permissions to use when creating the file, 
    ///                          or `nil` for default permissions, ignored if creation is not required.
    ///   - executor: The executor for executing the IO operations
    /// 
    /// The default permissions being used when `creationPermissions` is not specified are `0o644` for Posix
    /// and inheriting from parent directory for Windows.
    /// 
    /// - Attention: Windows does not support Posix style permissions directly, so this API will try to map
    ///              the Posix permissions to Windows DACL with best effort. If more fine-grained control is 
    ///              required, use the overloads that accept Windows security descriptors.
    /// 
    /// - Seealso: ``FileOperationOptions.OpenForWriting``
    @concurrent
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
    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - creationPermissions: The security descriptor specifying the permissions to use when creating the 
    ///                          file, ignored if creation is not required.
    ///   - executor: The executor for executing the IO operations
    /// 
    /// - Seealso: ``FileOperationOptions.OpenForWriting``
    @concurrent
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


    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - creationPermissions: The security descriptor specifying the permissions to use when creating the 
    ///                          file, ignored if creation is not required.
    ///   - executor: The executor for executing the IO operations
    /// 
    /// - Seealso: ``FileOperationOptions.OpenForWriting``
    @concurrent
    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: borrowing WindowsAbsoluteSecurityDescriptor,
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        try await self.init(forFileAt: path, options: options, creationPermissions: creationPermissions.view, executor: executor)
    }


    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - creationPermissions: The security descriptor specifying the permissions to use when creating the 
    ///                          file, ignored if creation is not required.
    ///   - executor: The executor for executing the IO operations
    /// 
    /// - Seealso: ``FileOperationOptions.OpenForWriting``
    @concurrent
    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: borrowing WindowsSelfRelativeSecurityDescriptor,
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        try await self.init(forFileAt: path, options: options, creationPermissions: creationPermissions.view, executor: executor)
    }
    #endif


    /// Closes the file handle, releases resources and ends the lifetime.
    /// 
    /// - Note: This method is not cancellable.
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
