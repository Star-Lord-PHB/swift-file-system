//
//  StreamingReadWriteHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



public struct StreamingReadWriteHandle
: ~Copyable
, SequentialReadFileHandleProtocol, SequentialWriteFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let path: FilePath


    init(unsafeHandleContext: consuming UnsafeHandleContext, path: FilePath) {
        self.context = unsafeHandleContext
        self.path = path
    }

}



extension StreamingReadWriteHandle {

    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForStreaming = .init()
    ) throws(PlatformError) {
        self.init(
            unsafeHandleContext: try .openForStreaming(at: path, access: .readWrite, options: options),
            path: path,
        )
    }


    package consuming func takeUnsafeHandleContext() -> UnsafeHandleContext {
        self.context
    }


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
