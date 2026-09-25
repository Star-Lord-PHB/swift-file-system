//
//  AsyncStreamingReadWriteHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// A file handle for sequentially reading and writing a file.
/// 
/// This handle supports "files" that are not regular files, such as fifos and character devices.
public struct AsyncStreamingReadWriteHandle
: ~Copyable
, AsyncSequentialReadFileHandleProtocol, AsyncSequentialWriteFileHandleProtocol
, AutoSynthesisAsyncFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let path: FilePath
    public let executor: AsyncFileSystemExecutor


    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - executor: The executor for executing the IO operations
    @concurrent
    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForStreaming = .init(),
        executor: AsyncFileSystemExecutor = .defaultExecutor
    ) async throws(PlatformError) {
        self.context = try await executor.runCancellable { () throws(PlatformError) in
            try StreamingReadWriteHandle(forFileAt: path, options: options)
        }
        .getThrowingPlatformError(operation: .open(path))
        .takeUnsafeHandleContext()
        self.executor = executor
        self.path = path
    }


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
