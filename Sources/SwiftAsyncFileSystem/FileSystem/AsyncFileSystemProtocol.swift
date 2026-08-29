//
//  AsyncFileSystemProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/28.
//

import SwiftFileSystem


/// Async counterpart of `FileSystemProtocol` for path-based operations.
///
/// Every method is `@concurrent`: it never executes on the caller's actor — the blocking
/// system calls run on a file-system executor, and the caller's actor is touched only when
/// the result is delivered. Throwing methods observe Swift task cancellation before the
/// blocking work starts and surface it as a `PlatformError` with kind `.cancelled` and no
/// `systemCode`, guaranteeing the operation has not been performed; once the blocking work
/// has started it always runs to completion and returns its result as usual.
///
/// The recursive operations (`removeItem`, `copyItem`) and the scoped handle APIs of the
/// synchronous protocol are not part of this surface yet.
public protocol AsyncFileSystemProtocol: Sendable {

    // MARK: Basic Operations

    @concurrent
    func itemExists(at path: FilePath, followSymlinks: Bool) async -> Bool

    @concurrent
    func createFile(at path: FilePath, replaceExisting: Bool, permissions: FilePermissions?, content: ByteBuffer?) async throws(PlatformError)

    // note: the permission will only be applied to the leaf directory, not the intermediate directories
    @concurrent
    func createDirectory(at path: FilePath, withIntermediateDirectories: Bool, permissions: FilePermissions?) async throws(PlatformError)

    #if canImport(WinSDK)
    @concurrent
    func createFile(at path: FilePath, replaceExisting: Bool, permissions: WindowsSecurityDescriptorView, content: ByteBuffer?) async throws(PlatformError)

    @concurrent
    func createDirectory(at path: FilePath, withIntermediateDirectories: Bool, permissions: WindowsSecurityDescriptorView) async throws(PlatformError)
    #endif

    @concurrent
    func moveItem(at srcPath: FilePath, to dstPath: FilePath, onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption) async throws(PlatformError)

    @concurrent
    func contentsOfDirectory(at path: FilePath, options: FileOperationOptions.DirectoryTraversalOption) async throws(PlatformError) -> [DirectoryEntry]

    @concurrent
    func createSymLink(at path: FilePath, pointingTo destPath: FilePath) async throws(PlatformError)

    @concurrent
    func createHardLink(at path: FilePath, for existingPath: FilePath) async throws(PlatformError)

    @concurrent
    func destinationOfSymLink(at path: FilePath, recursive: Bool) async throws(PlatformError) -> FilePath


    // MARK: File Information Operations

    @concurrent
    func info(ofItemAt path: FilePath, followSymlinks: Bool) async throws(PlatformError) -> FileInfo

    @concurrent
    func setTimes(
        forItemAt path: FilePath,
        accessTime: FileTimeSpec?,
        modificationTime: FileTimeSpec?,
        creationTime: FileTimeSpec?,
        followSymlink: Bool
    ) async throws(PlatformError)

    @concurrent
    func setAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes, followSymlink: Bool) async throws(PlatformError)

    #if canImport(Glibc) || canImport(Musl)
    @concurrent
    func getInodeFlags(forItemAt path: FilePath, followSymlink: Bool) async throws(PlatformError) -> LinuxInodeFlags

    @concurrent
    func setInodeFlags(forItemAt path: FilePath, flags: LinuxInodeFlags, followSymlink: Bool) async throws(PlatformError)
    #endif


    // MARK: File Permission Operations

    @concurrent
    func canAccess(itemAt path: FilePath, for accessMode: FileOperationOptions.FileAccessMode, followSymlink: Bool) async throws(PlatformError) -> Bool

    #if canImport(WinSDK)
    @concurrent
    func getSecurityInfo(
        forItemAt path: FilePath,
        querying: FileOperationOptions.WindowsSecurityInfoMembers,
        followSymlink: Bool
    ) async throws(PlatformError) -> sending WindowsSelfRelativeSecurityDescriptor

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
    @concurrent
    func getPosixPermissions(forItemAt path: FilePath, followSymlink: Bool) async throws(PlatformError) -> FilePermissions

    @concurrent
    func setPosixPermissions(forItemAt path: FilePath, permissions: FilePermissions, followSymlink: Bool) async throws(PlatformError)
    #endif

    @concurrent
    func getOwner(forItemAt path: FilePath, followSymlink: Bool) async throws(PlatformError) -> (owner: PlatformIdentity, group: PlatformIdentity)

    @concurrent
    func setOwner(forItemAt path: FilePath, owner: PlatformIdentity?, group: PlatformIdentity?, followSymlink: Bool) async throws(PlatformError)


    // MARK: Common Paths and Directories

    @concurrent
    func currentWorkingDirectoryPath() async throws(PlatformError) -> FilePath

    @concurrent
    func executablePath() async throws(PlatformError) -> FilePath

    @concurrent
    func homeDirectoryPath() async throws(PlatformError) -> FilePath

    @concurrent
    func tempDirectoryPath() async throws(PlatformError) -> FilePath

    @concurrent
    func cacheDirectoryPath() async throws(PlatformError) -> FilePath

}



#if canImport(WinSDK)
extension AsyncFileSystemProtocol {

    // These conveniences are deliberately not @concurrent: the owned descriptors are not
    // Sendable, so they stay borrowed in the caller's isolation and only the Sendable view
    // crosses to the @concurrent requirement.

    public func createFile(
        at path: FilePath,
        replaceExisting: Bool = false,
        permissions: borrowing WindowsAbsoluteSecurityDescriptor,
        content: ByteBuffer? = nil
    ) async throws(PlatformError) {
        try await createFile(at: path, replaceExisting: replaceExisting, permissions: permissions.view, content: content)
    }

    public func createFile(
        at path: FilePath,
        replaceExisting: Bool = false,
        permissions: borrowing WindowsSelfRelativeSecurityDescriptor,
        content: ByteBuffer? = nil
    ) async throws(PlatformError) {
        try await createFile(at: path, replaceExisting: replaceExisting, permissions: permissions.view, content: content)
    }


    public func createDirectory(
        at path: FilePath,
        withIntermediateDirectories: Bool = false,
        permissions: borrowing WindowsAbsoluteSecurityDescriptor
    ) async throws(PlatformError) {
        try await createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, permissions: permissions.view)
    }

    public func createDirectory(
        at path: FilePath,
        withIntermediateDirectories: Bool = false,
        permissions: borrowing WindowsSelfRelativeSecurityDescriptor
    ) async throws(PlatformError) {
        try await createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, permissions: permissions.view)
    }

}
#endif
