import struct SwiftFileSystem.DirectoryEntry
import enum SwiftFileSystem.FileOperationOptions



public protocol AsyncDirectoryHandleProtocol: AsyncFileHandleProtocol, ~Copyable, ~Escapable {

    // MARK: TODO: Add entrySequence into protocol when non-copyable associated types in protocols are supported
    // associatedtype DirectoryEntryDirectSequenceType: DirectoryEntryDirectSequenceProtocol & ~Escapable & ~Copyable
    // 
    // @_lifetime(borrow self)
    // func entrySequence(options: FileOperationOptions.DirectoryTraversalOption) -> DirectoryEntryDirectSequenceType

    @concurrent
    func entries(options: FileOperationOptions.DirectoryTraversalOption) async throws(PlatformError) -> [DirectoryEntry]

}
