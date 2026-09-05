//
//  DirectoryHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



public protocol DirectoryHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    // MARK: TODO: Add entrySequence into protocol when non-copyable associated types in protocols are supported
    // associatedtype DirectoryEntryDirectSequenceType: DirectoryEntryDirectSequenceProtocol & ~Escapable & ~Copyable
    // 
    // @_lifetime(borrow self)
    // func entrySequence(options: FileOperationOptions.DirectoryTraversalOption) -> DirectoryEntryDirectSequenceType

    func entries(options: FileOperationOptions.DirectoryTraversalOption) throws(PlatformError) -> [DirectoryEntry]

}
