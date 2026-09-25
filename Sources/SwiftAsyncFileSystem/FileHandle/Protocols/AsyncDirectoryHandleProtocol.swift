import struct SwiftFileSystem.DirectoryEntry
import enum SwiftFileSystem.FileOperationOptions



/// A protocol for file handles for directories.
public protocol AsyncDirectoryHandleProtocol: AsyncFileHandleProtocol, ~Copyable, ~Escapable {

    // MARK: TODO: Add entrySequence into protocol when non-copyable associated types in protocols are supported
    // associatedtype DirectoryEntryDirectSequenceType: DirectoryEntryDirectSequenceProtocol & ~Escapable & ~Copyable
    // 
    // @_lifetime(borrow self)
    // func entrySequence(options: FileOperationOptions.DirectoryTraversalOption) -> DirectoryEntryDirectSequenceType

    /// Gets all the direct entries in the directory.
    /// 
    /// - Parameter options: The options for directory traversal.
    @concurrent
    func entries(options: FileOperationOptions.DirectoryTraversalOption) async throws(PlatformError) -> [DirectoryEntry]

}
