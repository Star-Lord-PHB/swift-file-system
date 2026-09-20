//
//  SyncHandleAdapter.swift
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
struct SyncHandleAdapter
: ~Copyable, ~Escapable
, PositionalReadFileHandleProtocol, PositionalWriteFileHandleProtocol
, SequentialReadFileHandleProtocol, SequentialWriteFileHandleProtocol
, PersistentFileHandleProtocol, ResizableFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    let handle: UnsafeHandleContextView
    let path: FilePath


    @_lifetime(borrow unsafeHandleContext)
    init(unsafeHandleContext: borrowing UnsafeHandleContext, path: FilePath) {
        self.init(unsafeHandleContext: unsafeHandleContext.view, path: path)
    }


    @_lifetime(copy unsafeHandleContext)
    init(unsafeHandleContext: UnsafeHandleContextView, path: FilePath) {
        self.handle = unsafeHandleContext
        self.path = path
    }


    var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(copy self) get { handle }
    }

}
