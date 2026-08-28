//
//  StreamingReadHandle.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



public struct StreamingReadHandle
: ~Copyable
, SequentialReadFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle
    public let path: FilePath


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension StreamingReadHandle {

    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForStreaming = .init()
    ) throws(PlatformError) {
        self.init(
            unsafeSystemHandle: try StreamingOpen.open(at: path, access: .readOnly(), options: options),
            path: path
        )
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
