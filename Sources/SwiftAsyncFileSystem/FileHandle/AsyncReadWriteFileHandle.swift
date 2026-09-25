//
//  AsyncReadWriteFileHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// A file handle for positionally reading and writing a file.
public struct AsyncReadWriteFileHandle
: ~Copyable, @unchecked Sendable
, AsyncPositionalReadFileHandleProtocol
, AsyncPositionalWriteFileHandleProtocol, AsyncPersistentFileHandleProtocol
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
            try ReadWriteFileHandle(forFileAt: path, options: options, creationPermissions: creationPermissions)
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
            try ReadWriteFileHandle(forFileAt: path, options: options, creationPermissions: creationPermissions)
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

}



extension AsyncReadWriteFileHandle {

    /// Gets a sequential accessor for this file handle.
    @_lifetime(borrow self)
    public func sequentialAccessor() -> SequentialAccessor {
        .init(readWriteHandle: self)
    }


    /// A sequential accessor for both reading and writing supported by a positional read-write file handle.
    /// 
    /// The sequential read/write operations provided by this accessor are based on a manually maintained 
    /// file pointer instead of relying on the one provided by the underlying file system. As a result, each 
    /// instance have independent file pointer.
    public struct SequentialAccessor
    : ~Escapable
    , AsyncMutatingSequentialReadFileHandleProtocol
    , AsyncMutatingSequentialWriteFileHandleProtocol, AsyncMutatingSeekableFileHandleProtocol
    , AsyncResizableFileHandleProtocol, AsyncPersistentFileHandleProtocol
    , AutoSynthesisAsyncFileHandleProtocol {

        private var accessor: AsyncPositionalHandleAccessor

        public var executor: AsyncFileSystemExecutor { accessor.executor }
        public var path: FilePath { accessor.path }

        public var currentOffset: Int64 { accessor.currentOffset }


        @_lifetime(borrow readWriteHandle)
        init(readWriteHandle: borrowing AsyncReadWriteFileHandle) {
            self.accessor = .init(
                unsafeHandleContext: readWriteHandle.context, 
                path: readWriteHandle.path, 
                executor: readWriteHandle.executor
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


        @concurrent
        @discardableResult
        @_lifetime(self: copy self)
        public mutating func write(_ bytes: RawSpan) async throws(PlatformError) -> Int64 {
            try await accessor.write(bytes)
        }

    }

}
