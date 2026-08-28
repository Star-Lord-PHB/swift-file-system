//
//  DirectoryHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/25.
//

import struct SystemPackage.FilePath
import FileSystemCore



public protocol DirectoryHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

        // MARK: TODO: Migrate to associatedtype when non-copyable associated types in protocols are supported
        // associatedtype DirectoryEntryDirectSequenceType: DirectoryEntryDirectSequenceProtocol & ~Escapable & ~Copyable
        // associatedtype DirectoryEntryRecursiveSequenceType: DirectoryEntryRecursiveSequenceProtocol & ~Escapable & ~Copyable
    typealias DirectoryEntryRecursiveSequenceType = any (DirectoryEntryRecursiveSequenceProtocol & ~Escapable & ~Copyable)
    typealias DirectoryEntryDirectSequenceType = any (DirectoryEntryDirectSequenceProtocol & ~Escapable & ~Copyable)

    func directEntries(options: FileOperationOptions.DirectoryTraversalOption) throws(PlatformError) -> [DirectoryEntry]

    @_lifetime(borrow self)
    func entryDirectSequence(options: FileOperationOptions.DirectoryTraversalOption) -> DirectoryEntryDirectSequenceType

    @_lifetime(borrow self)
    func entryRecursiveSequence(options: FileOperationOptions.DirectoryTraversalOption) -> DirectoryEntryRecursiveSequenceType

}

