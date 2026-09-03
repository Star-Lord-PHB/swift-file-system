//
//  StreamingWriteHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



public struct StreamingWriteHandle
: ~Copyable
, SequentialWriteFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle
    public let path: FilePath


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension StreamingWriteHandle {

    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForStreaming = .init()
    ) throws(PlatformError) {
        self.init(
            unsafeSystemHandle: try StreamingOpen.open(at: path, access: .writeOnly(), options: options),
            path: path
        )
    }


    package consuming func takeUnsafeSystemHandle() -> UnsafeSystemHandle {
        self.handle
    }


    public consuming func close() throws(PlatformError) {
        do {
            try handle.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}
