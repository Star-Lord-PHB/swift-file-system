//
//  StreamingReadHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



/// A file handle for sequentially reading a file.
/// 
/// This handle supports "files" that are not regular files, such as fifos and character devices.
public struct StreamingReadHandle
: ~Copyable
, SequentialReadFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let path: FilePath


    init(unsafeHandleContext: consuming UnsafeHandleContext, path: FilePath) {
        self.context = unsafeHandleContext
        self.path = path
    }

}



extension StreamingReadHandle {

    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForStreaming = .init()
    ) throws(PlatformError) {
        self.init(
            unsafeHandleContext: try .openForStreaming(at: path, access: .readOnly, options: options),
            path: path,
        )
    }


    package consuming func takeUnsafeHandleContext() -> UnsafeHandleContext {
        self.context
    }


    /// Closes the file handle, releases resources and ends the lifetime.
    public consuming func close() throws(PlatformError) {
        do {
            try context.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get { context.view }
    }

}
