//
//  SyncHandleView.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem
internal import FileSystemCore


/// Borrowed synchronous view over an async handle's system handle, used on executor worker
/// threads to reuse the synchronous protocol default implementations (EOF and negative
/// offset alignment, error contexts) without duplicating them in the async layer.
///
/// The view conforms to every synchronous capability protocol at once; each async handle
/// only reaches the subset its own protocols forward to.
struct SyncHandleView
: ~Copyable, ~Escapable
, PositionalReadFileHandleProtocol, PositionalWriteFileHandleProtocol
, SequentialReadFileHandleProtocol, SequentialWriteFileHandleProtocol
, PersistentFileHandleProtocol, ResizableFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    let handle: UnsafeUnownedSystemHandle
    let path: FilePath


    @_lifetime(borrow systemHandle)
    init(systemHandle: borrowing UnsafeSystemHandle, path: FilePath) {
        self.handle = systemHandle.unownedHandle()
        self.path = path
    }


    @_lifetime(copy unownedHandle)
    init(unownedHandle: UnsafeUnownedSystemHandle, path: FilePath) {
        self.handle = unownedHandle
        self.path = path
    }


    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try self.handle.unsafeTemporaryConvertingToOwning { handle throws(E) in
            try body(handle)
        }
    }

}
