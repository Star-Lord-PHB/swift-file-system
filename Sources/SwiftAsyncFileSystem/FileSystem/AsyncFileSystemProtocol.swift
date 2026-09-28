//
//  AsyncFileSystemProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/28.
//

import SwiftFileSystem


/// A protocol for path-based file system APIs.
public protocol AsyncFileSystemProtocol: Sendable {

    // MARK: Basic Operations

    /// Checks if an item exists at the specified path.
    /// - Parameters:
    ///   - path: The path to check.
    ///   - followSymlink: Whether to follow symbolic links.
    /// 
    /// - Note: Errors are treated as not exist.
    @concurrent
    func itemExists(at path: FilePath, followSymlink: Bool) async -> Bool

    /// Creates a new file at the specified path.
    /// - Parameters:
    ///   - path: The path to create the new file.
    ///   - replaceExisting: Whether to replace the existing file if there is one.
    ///   - permissions: The permissions for the new file, or `nil` to use the default permissions, 
    ///                  ignored if there is an existing file.
    ///   - content: The content to write to the new file, or `nil` for an empty file.
    /// 
    /// The default permissions being used when `creationPermissions` is not specified are `0o644` for Posix
    /// and inheriting from parent directory for Windows.
    /// 
    /// - Attention: Windows does not support Posix style permissions directly, so this API will try to map
    ///              the Posix permissions to Windows DACL with best effort. If more fine-grained control is 
    ///              required, use the overloads that accept Windows security descriptors.
    @concurrent
    func createFile(at path: FilePath, replaceExisting: Bool, permissions: FilePermissions?, content: ByteBuffer?) async throws(PlatformError)

    /// Creates a new directory at the specified path.
    /// - Parameters:
    ///   - path: The path to create the new directory.
    ///   - withIntermediateDirectories: Whether to create intermediate directories if they do not exist.
    ///   - permissions: The permissions for the new directory, or `nil` to use the default permissions,
    ///                  ignored if there is an existing directory.
    /// 
    /// The default permissions being used when `creationPermissions` is not specified are `0o755` for Posix
    /// and inheriting from parent directory for Windows.
    /// 
    /// - Attention: the permission will only be applied to the leaf directory, not the intermediate 
    ///              directories
    /// 
    /// - Attention: Windows does not support Posix style permissions directly, so this API will try to map
    ///              the Posix permissions to Windows DACL with best effort. If more fine-grained control is 
    ///              required, use the overloads that accept Windows security descriptors.
    @concurrent
    func createDirectory(at path: FilePath, withIntermediateDirectories: Bool, permissions: FilePermissions?) async throws(PlatformError)

    #if canImport(WinSDK)
    /// Creates a new file at the specified path.
    /// - Parameters:
    ///   - path: The path to create the new file.
    ///   - replaceExisting: Whether to replace the existing file if there is one.
    ///   - permissions: The security descriptor specifying the permissions for the new file, ignored if
    ///                  there is an existing file.
    ///   - content: The content to write to the new file, or `nil` for an empty file.
    @concurrent
    func createFile(at path: FilePath, replaceExisting: Bool, permissions: WindowsSecurityDescriptorView, content: ByteBuffer?) async throws(PlatformError)

    /// Creates a new directory at the specified path.
    /// - Parameters:
    ///   - path: The path to create the new directory.
    ///   - withIntermediateDirectories: Whether to create intermediate directories if they do not exist.
    ///   - permissions: The security descriptor specifying the permissions for the new directory, ignored 
    ///                  if there is an existing directory.
    /// 
    /// - Attention: the permission will only be applied to the leaf directory, not the intermediate 
    ///              directories
    @concurrent
    func createDirectory(at path: FilePath, withIntermediateDirectories: Bool, permissions: WindowsSecurityDescriptorView) async throws(PlatformError)
    #endif

    /// Removes the item at the specified path.
    /// - Parameter path: The path of the item to remove.
    /// 
    /// If the item is a non-empty directory, recursively remove all its children. If errors occur during 
    /// the recursive removal, the operation will still continue to the end and only throw the first error
    /// occurred.
    /// 
    /// - Note: This method never follows symbolic links. Applying it on a symbolic link will remove the link
    ///        itself instead of the target.
    @concurrent
    func removeItem(at path: FilePath) async throws(PlatformError)

    /// Copies the item at the specified path to another location.
    /// - Parameters:
    ///   - srcPath: The path of the item to copy.
    ///   - dstPath: The destination path to copy the item to.
    ///   - options: The options for copying the item.
    ///   - errorStrategy: The strategy to handle errors during the copy operation. This will affect
    ///                    what is returned and thrown.
    /// 
    /// If the source item is a directory, recursively copy all its children.
    /// 
    /// # Supported Item Types
    /// 
    /// The copy operation only support the following item types as the source item:
    /// * Regular file
    /// * Symbolic link
    /// * Directory
    /// 
    /// Unsupported items will be reported as an error.
    /// 
    /// # Replacing Existing Items
    /// 
    /// When the the destination already exists and ``FileOperationOptions/CopyItemOptions/existingTarget``
    /// is set to ``FileOperationOptions/CopyTargetExistOption/overwrite``, the operation will try to replace
    /// the existing item with the following rules:
    /// 
    /// | Source Type | Destination Type | Behavior |
    /// | --- | --- | --- |
    /// | File / Symlink | File / Symlink | Replace |
    /// | File / Symlink | Directory | Fails |
    /// | Directory | non-Directory | Fails |
    /// | Directory | Directory | Merge (keep non-conflicting items at the destination) |
    /// 
    /// Note that when the existing destination item is not a file, symbolic link or directory, the operation
    /// will report an error without replacing it regardless of the source item type.
    /// 
    /// # Error Strategy
    /// 
    /// The `errorStrategy` parameter allows specifying the behavior when an error occurs during the copy 
    /// operation and controls how the errors should be reported. 
    /// 
    /// The copy operation will report errors on each individual steps (described in 
    /// ``RecursiveCopyResult/ItemOperation``) on each item being copied to the strategy. The stragegy can
    /// then decide whether to collect that error and whether to continue the copy operation or abort it. 
    /// 
    /// When the strategy decides to continue, the behavior may still vary depending on the step that failed:
    /// * Errors in steps for retrieving the metadata of the source item will stop the current item and move 
    ///   on to the next one, since the operation cannot decide how to copy it.
    /// * Errors in content copy errors for files / symlinks will stop the current item and move on to the 
    ///   next one.
    /// * Errors in steps for writing metadata does not stop the current item from being copied, but the 
    ///   resulting item may not have the complete metadata copied.
    /// * Errors in steps for releasing resources will not stop the current item from being copied.
    /// * Errors in the directory enumeration will unconditionally abort the whole copy operation.
    /// 
    /// There are 4 built-in strategies:
    /// 
    /// | Strategy | Description | Returns | Throws |
    /// | --- | --- | --- | --- |
    /// | ``FileOperationOptions/RecursiveCopyErrorStrategyProtocol/abortOnError`` | Abort the copy operation on the first error | Void | PlatformError |
    /// | ``FileOperationOptions/RecursiveCopyErrorStrategyProtocol/collectAndThrow`` | Collect all errors and report them as a thrown error | Void | PlatformError |
    /// | ``FileOperationOptions/RecursiveCopyErrorStrategyProtocol/collectAndReturn`` | Collect all errors and return them as a result | RecursiveCopyResult | Never |
    /// | ``FileOperationOptions/RecursiveCopyErrorStrategyProtocol/ignoreAll`` | Ignore all errors and continue the copy operation | Void | PlatformError |
    /// 
    /// Note that the `.ignoreAll` strategy still throws if the copy operation is cancelled.
    /// 
    /// - Seealso: ``FileOperationOptions/CopyItemOptions``
    /// - Seealso: ``FileOperationOptions/RecursiveCopyErrorStrategyProtocol``
    @concurrent
    func copyItem<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>(
        at srcPath: FilePath,
        to dstPath: FilePath,
        options: FileOperationOptions.CopyItemOptions,
        errorStrategy: ErrorStrategy
    ) async throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.Returned

    /// Moves the item at the specified path to another location.
    /// - Parameters:
    ///   - srcPath: The path of the item to move.
    ///   - dstPath: The destination path to move the item to.
    ///   - targetExistOption: The behavior when the destination already exists.
    /// 
    /// When the `existingTargetOption` is set to ``FileOperationOptions/CopyTargetExistOption/overwrite``,
    /// the behavior may vary depending on the type of the source and destination items:
    /// 
    /// | Source Type | Destination Type | Behavior |
    /// | --- | --- | --- |
    /// | File | File | Replace |
    /// | File | Directory | Fails |
    /// | Directory | File | Fails |
    /// | Directory | Empty Directory | Replace |
    /// | Directory | Non-Empty Directory | Fails |
    @concurrent
    func moveItem(at srcPath: FilePath, to dstPath: FilePath, onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption) async throws(PlatformError)

    /// Gets all the direct entries of the directory at the specified path.
    /// - Parameters:
    ///   - path: The path of the directory to read.
    ///   - options: The options for enumerating the entries.
    @concurrent
    func contentsOfDirectory(at path: FilePath, options: FileOperationOptions.DirectoryTraversalOption) async throws(PlatformError) -> [DirectoryEntry]

    /// Creates a symbolic link at the specified path pointing to the specified destination path.
    /// - Parameters:
    ///   - path: The path for creating the symbolic link.
    ///   - destPath: The path that the symbolic link points to. Does not required to be a path to an 
    ///     existing item. If relative, it should be relative to the symbolic link itself.
    @concurrent
    func createSymLink(at path: FilePath, pointingTo destPath: FilePath) async throws(PlatformError)

    /// Creates a hard link at the specified path for an existing item.
    /// - Parameters:
    ///   - path: The path for creating the hard link.
    ///   - existingPath: The path to the existing item to create a hard link for. The existing item must 
    ///                   exist.
    @concurrent
    func createHardLink(at path: FilePath, for existingPath: FilePath) async throws(PlatformError)

    /// Gets the destination path of a symbolic link at the specified path.
    /// - Parameters:
    ///   - path: The path of the symbolic link to resolve.
    ///   - recursive: Whether to recursively resolve the symbolic link.
    /// 
    /// This method has completely different semantics depending on the `recursive` parameter:
    /// * if `false`: Only the direct target stored in the link is read, and the specified path must be a 
    ///   symbolic link
    /// * If `true`, the specified path will be resolved recursively until reaching a absolute path without 
    ///   any symbolic link components, and the specified path can be arbitraty type.
    @concurrent
    func destinationOfSymLink(at path: FilePath, recursive: Bool) async throws(PlatformError) -> FilePath


    // MARK: File Information Operations

    /// Gets the metadata of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item to get the metadata for.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the metadata of the symbolic link
    ///                    itself will be retrieved instead of the target.
    @concurrent
    func info(ofItemAt path: FilePath, followSymlink: Bool) async throws(PlatformError) -> FileInfo

    /// Updates the file times of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item to update the file times for.
    ///   - access: The new last access time, or `nil` to leave unchanged.
    ///   - modification: The new last modification time, or `nil` to leave unchanged
    ///   - creation: The new creation time, or `nil` to leave unchanged.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the file times of the symbolic link
    ///                    itself will be updated instead of the target.
    /// 
    /// > Attention: 
    /// > The behavior of this method varies across platforms:
    /// > * On Linux, setting the creation time is not supported and will be ignored.
    /// > * On Darwin and BSD, the new creation time cannot be later than the modification time.
    @concurrent
    func setTimes(
        forItemAt path: FilePath,
        access: FileTimeSpec?,
        modification: FileTimeSpec?,
        creation: FileTimeSpec?,
        followSymlink: Bool
    ) async throws(PlatformError)

    /// Updates the file attributes (flags) of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item to update the file attributes for.
    ///   - attributes: The new file attributes to set.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the file attributes of the symbolic
    ///                    link itself will be updated instead of the target.
    @concurrent
    func setAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes, followSymlink: Bool) async throws(PlatformError)

    #if os(Linux) || os(Android)
    /// Gets the inode flags of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item to get the inode flags for.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the inode flags of the symbolic link
    ///                    itself will be retrieved instead of the target.
    @concurrent
    func inodeFlags(ofItemAt path: FilePath, followSymlink: Bool) async throws(PlatformError) -> LinuxInodeFlags

    /// Updates the inode flags of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item to update the inode flags for.
    ///   - flags: The new inode flags to set.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the inode flags of the symbolic
    ///                    link itself will be updated instead of the target.
    @concurrent
    func setInodeFlags(forItemAt path: FilePath, flags: LinuxInodeFlags, followSymlink: Bool) async throws(PlatformError)
    #endif


    // MARK: File Permission Operations

    /// Checks if the current process is able to access the item at the specified path with the 
    /// specified access mode.
    /// - Parameters:
    ///   - path: The path to the item to check access for.
    ///   - accessMode: The access mode to check.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the access to the symbolic link 
    ///                    itself will be checked instead of the target.
    @concurrent
    func canAccess(itemAt path: FilePath, for accessMode: FileOperationOptions.FileAccessMode, followSymlink: Bool) async throws(PlatformError) -> Bool

    /// Gets the Windows security descriptor of the item at the specified path.
    /// - Parameters: 
    ///   - path: The path to the item for which to retrieve the security descriptor.
    ///   - members: The members of the security descriptor to retrieve.
    ///  - followSymlink: Whether to follow symbolic links. If `false`, the security descriptor of the
    ///                   symbolic link itself will be retrieved instead of the target.
    #if canImport(WinSDK)
    @concurrent
    func securityInfo(
        ofItemAt path: FilePath,
        querying members: FileOperationOptions.WindowsSecurityInfoMembers,
        followSymlink: Bool
    ) async throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor

    /// Updates the Windows security descriptor of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item for which to update the security descriptor.
    ///   - dacl: How to update the DACL. 
    ///           Can be replacing with a new DACL, removing it or leaving it unchanged.
    ///   - sacl: How to update the SACL.
    ///           Can be replacing with a new SACL, removing it or leaving it unchanged.
    ///   - owner: The new owner to set, or `nil` to leave unchanged.
    ///   - group: The new group to set, or `nil` to leave unchanged.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the security descriptor of the
    ///                    symbolic link itself will be updated instead of the target.
    /// 
    /// - Seealso: ``FileOperationOptions/WindowsAclUpdateRequest``
    @concurrent
    func setSecurityInfo(
        forItemAt path: FilePath,
        dacl: FileOperationOptions.WindowsAclUpdateRequest,
        sacl: FileOperationOptions.WindowsAclUpdateRequest,
        owner: PlatformIdentity?,
        group: PlatformIdentity?,
        followSymlink: Bool
    ) async throws(PlatformError)
    #else
    /// Gets the POSIX permissions of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item for which to retrieve the permissions.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the permissions of the symbolic link
    ///                    itself will be retrieved instead of the target.
    @concurrent
    func posixPermissions(ofItemAt path: FilePath, followSymlink: Bool) async throws(PlatformError) -> FilePermissions

    /// Updates the POSIX permissions of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item for which to update the permissions.
    ///   - permissions: The new POSIX permissions to set.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the permissions of the symbolic link
    ///                    itself will be updated instead of the target.
    @concurrent
    func setPosixPermissions(forItemAt path: FilePath, permissions: FilePermissions, followSymlink: Bool) async throws(PlatformError)
    #endif

    /// Gets the owner and group of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item for which to retrieve the owner and group.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the owner and group of the symbolic 
    ///                    link itself will be retrieved instead of the target.
    @concurrent
    func owner(ofItemAt path: FilePath, followSymlink: Bool) async throws(PlatformError) -> (owner: PlatformIdentity, group: PlatformIdentity)

    /// Updates the owner and group of the item at the specified path.
    /// - Parameters:
    ///   - path: The path to the item for which to update the owner and group.
    ///   - owner: The new owner to set, or `nil` to leave unchanged.
    ///   - group: The new group to set, or `nil` to leave unchanged.
    ///   - followSymlink: Whether to follow symbolic links. If `false`, the owner and group of the symbolic
    ///                    link itself will be updated instead of the target.
    @concurrent
    func setOwner(forItemAt path: FilePath, owner: PlatformIdentity?, group: PlatformIdentity?, followSymlink: Bool) async throws(PlatformError)


    // MARK: Common Paths and Directories

    /// Gets the path to the current working directory of the process.
    @concurrent
    func currentWorkingDirectoryPath() async throws(PlatformError) -> FilePath

    /// Gets the path to the executable of the current process.
    @concurrent
    func executablePath() async throws(PlatformError) -> FilePath

    /// Gets the path to the home directory of the current user.
    @concurrent
    func homeDirectoryPath() async throws(PlatformError) -> FilePath

    /// Get the path to the temporary directory of the current process.
    @concurrent
    func tempDirectoryPath() async throws(PlatformError) -> FilePath

    /// Gets the path to the cache directory of the current process.
    @concurrent
    func cacheDirectoryPath() async throws(PlatformError) -> FilePath

}



#if canImport(WinSDK)
extension AsyncFileSystemProtocol {

    /// Creates a new file at the specified path.
    /// - Parameters:
    ///   - path: The path to create the new file.
    ///   - replaceExisting: Whether to replace the existing file if there is one.
    ///   - permissions: The security descriptor specifying the permissions for the new file, ignored if
    ///                  there is an existing file.
    ///   - content: The content to write to the new file, or `nil` for an empty file.
    @concurrent
    public func createFile(
        at path: FilePath,
        replaceExisting: Bool = false,
        permissions: borrowing WindowsAbsoluteSecurityDescriptor,
        content: ByteBuffer? = nil
    ) async throws(PlatformError) {
        try await createFile(at: path, replaceExisting: replaceExisting, permissions: permissions.view, content: content)
    }

    /// Creates a new file at the specified path.
    /// - Parameters:
    ///   - path: The path to create the new file.
    ///   - replaceExisting: Whether to replace the existing file if there is one.
    ///   - permissions: The security descriptor specifying the permissions for the new file, ignored if
    ///                  there is an existing file.
    ///   - content: The content to write to the new file, or `nil` for an empty file.
    @concurrent
    public func createFile(
        at path: FilePath,
        replaceExisting: Bool = false,
        permissions: borrowing WindowsSelfRelativeSecurityDescriptor,
        content: ByteBuffer? = nil
    ) async throws(PlatformError) {
        try await createFile(at: path, replaceExisting: replaceExisting, permissions: permissions.view, content: content)
    }


    /// Creates a new directory at the specified path.
    /// - Parameters:
    ///   - path: The path to create the new directory.
    ///   - withIntermediateDirectories: Whether to create intermediate directories if they do not exist.
    ///   - permissions: The security descriptor specifying the permissions for the new directory, ignored 
    ///                  if there is an existing directory.
    /// 
    /// - Attention: the permission will only be applied to the leaf directory, not the intermediate 
    ///              directories
    @concurrent
    public func createDirectory(
        at path: FilePath,
        withIntermediateDirectories: Bool = false,
        permissions: borrowing WindowsAbsoluteSecurityDescriptor
    ) async throws(PlatformError) {
        try await createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, permissions: permissions.view)
    }

    /// Creates a new directory at the specified path.
    /// - Parameters:
    ///   - path: The path to create the new directory.
    ///   - withIntermediateDirectories: Whether to create intermediate directories if they do not exist.
    ///   - permissions: The security descriptor specifying the permissions for the new directory, ignored 
    ///                  if there is an existing directory.
    /// 
    /// - Attention: the permission will only be applied to the leaf directory, not the intermediate 
    ///              directories
    @concurrent
    public func createDirectory(
        at path: FilePath,
        withIntermediateDirectories: Bool = false,
        permissions: borrowing WindowsSelfRelativeSecurityDescriptor
    ) async throws(PlatformError) {
        try await createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, permissions: permissions.view)
    }

}
#endif
