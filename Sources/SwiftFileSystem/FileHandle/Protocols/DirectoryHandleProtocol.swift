//
//  DirectoryHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import SystemPackage
import FileSystemCore



/// A protocol for file handles for directories.
public protocol DirectoryHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    // MARK: TODO: Add entrySequence into protocol when non-copyable associated types in protocols are supported
    // associatedtype DirectoryEntryDirectSequenceType: DirectoryEntryDirectSequenceProtocol & ~Escapable & ~Copyable
    // 
    // @_lifetime(borrow self)
    // func entrySequence(options: FileOperationOptions.DirectoryTraversalOption) -> DirectoryEntryDirectSequenceType

    /// Gets all the direct entries in the directory.
    /// 
    /// - Parameter options: The options for directory traversal.
    func entries(options: FileOperationOptions.DirectoryTraversalOption) throws(PlatformError) -> [DirectoryEntry]

}
