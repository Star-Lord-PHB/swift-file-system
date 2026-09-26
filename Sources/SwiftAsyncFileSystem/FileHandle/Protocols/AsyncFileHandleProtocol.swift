//
//  AsyncFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// A protocol for general file handles.
public protocol AsyncFileHandleProtocol: ~Copyable, ~Escapable {
    /// The path to the item where this handle is opened.
    var path: FilePath { get }
}



/// A protocol for file handles with operations executed on a specific ``AsyncFileSystemExecutor``.
public protocol ExecutorSupportedAsyncFileHandleProtocol: ~Copyable, ~Escapable {
    /// The executor on which the operations of this handle are executed.
    var executor: AsyncFileSystemExecutor { get }
}



/// A protocol for file handles that can provide an ``UnsafeSystemHandle`` and associated opening context.
public protocol SystemHandleSupportedAsyncFileHandleProtocol: ~Copyable, ~Escapable {

    /// Gets an unowned view to the underlying ``UnsafeSystemHandle`` and associated opening context.
    var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get
    }

}



extension SystemHandleSupportedAsyncFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Access the underlying ``UnsafeSystemHandle`` in a closure.
    /// 
    /// - Parameter operation: A closure for accessing the underlying ``UnsafeSystemHandle``.
    /// 
    /// - Warning: Do not return or store the ``UnsafeSystemHandle`` outside of the closure.
    @concurrent
    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> R
    ) async throws(E) -> R {
        try await unsafeHandleContext.withUnsafeSystemHandle(operation)
    }

}



/// A protocol for file handles that can provide an ``UnsafeSystemHandle`` with associated opening context 
/// and have its operations executed on a specific ``AsyncFileSystemExecutor``.
public protocol AutoSynthesisAsyncFileHandleProtocol
: ~Copyable, ~Escapable
, ExecutorSupportedAsyncFileHandleProtocol, SystemHandleSupportedAsyncFileHandleProtocol {}



extension AutoSynthesisAsyncFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Access the unowned view to the underlying ``UnsafeSystemHandle`` and associated opening context in
    /// a closure executed on the handle's ``ExecutorSupportedAsyncFileHandleProtocol/executor``.
    /// 
    /// - Parameter operation: A closure executed on the executor for accessing the unowned view to the 
    ///                        underlying ``UnsafeSystemHandle`` with associated opening context.
    @concurrent
    public func withUnsafeHandleContextInExecutor<R: ~Copyable, E: Error>(
        _ operation: (UnsafeHandleContextView) throws(E) -> R
    ) async -> AsyncFileSystemExecutor.Result<R, E> {
        await executor.runCancellable { () throws(E) in
            try operation(unsafeHandleContext)
        }
    }


    /// Access the underlying ``UnsafeSystemHandle`` in a closure executed on the handle's 
    /// ``ExecutorSupportedAsyncFileHandleProtocol/executor``.
    /// - Parameter operation: A closure executed on the executor for accessing the underlying 
    ///                        ``UnsafeSystemHandle``.
    /// 
    /// - Warning: Do not return or store the ``UnsafeSystemHandle`` outside of the closure.
    @concurrent
    public func withUnsafeSystemHandleInExecutor<R: ~Copyable, E: Error>(
        _ operation: (borrowing UnsafeSystemHandle) throws(E) -> R
    ) async -> AsyncFileSystemExecutor.Result<R, E> {
        await self.withUnsafeSystemHandle { handle in
            await executor.runCancellable { () throws(E) in
                try operation(handle)
            }
        }
    }

}



extension AsyncFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    func withSyncHandleAdapterInExecutor<R: ~Copyable>(
        _ task: (borrowing SyncHandleAdapter) throws(PlatformError) -> R
    ) async -> AsyncFileSystemExecutor.Result<R, PlatformError> {
        let adapter = SyncHandleAdapter(unsafeHandleContext: unsafeHandleContext, path: path)
        return await executor.runCancellable { () throws(PlatformError) in
            try task(adapter)
        }
    }


    /// Gets the metadata of the item referred by this handle.
    @concurrent
    public func fileInfo() async throws(PlatformError) -> FileInfo {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.fileInfo()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    /// Gets the type of the item referred by this handle.
    @concurrent
    public func type() async throws(PlatformError) -> FileKind {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.type()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    /// Gets the file times of the item referred by this handle.
    /// 
    /// - Last access time
    /// - Last modification time
    /// - Status change time
    /// - Creation time (if supported by the platform)
    @concurrent
    public func fileTimes() async throws(PlatformError) -> FileTimes {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.fileTimes()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    /// Updates the file times of the item referred by this handle.
    /// - Parameters:
    ///   - access: The new last access time, or `nil` to leave unchanged.
    ///   - modification: The new last modification time, or `nil` to leave unchanged
    ///   - creation: The new creation time, or `nil` to leave unchanged.
    /// 
    /// > Attention: 
    /// > The behavior of this method varies across platforms:
    /// > * On Linux, setting the creation time is not supported and will be ignored.
    /// > * On Darwin and BSD, the new creation time cannot be later than the modification time.
    @concurrent
    public func setFileTimes(
        access: FileTimeSpec? = nil,
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setFileTimes(access: access, modification: modification, creation: creation)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }


    /// Gets the file attributes (flags) of the item referred by this handle.
    @concurrent
    public func fileAttributes() async throws(PlatformError) -> PlatformFileAttributes {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.fileAttributes()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    /// Updates the file attributes (flags) of the item referred by this handle.
    /// - Parameter attributes: The new file attributes to set.
    @concurrent
    public func setFileAttributes(_ attributes: PlatformFileAttributes) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setFileAttributes(attributes)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }


    #if os(Linux) || os(Android)
    /// Gets the inode flags of the item referred by this handle.
    @concurrent
    public func inodeFlags() async throws(PlatformError) -> LinuxInodeFlags {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.inodeFlags()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    /// Updates the inode flags of the item referred by this handle.
    /// - Parameter flags: The new inode flags to set.
    @concurrent
    public func setInodeFlags(_ flags: LinuxInodeFlags) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setInodeFlags(flags)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }
    #endif


    #if canImport(WinSDK)
    /// Gets the Windows security descriptor of the item referred by this handle.
    /// - Parameter members: The members of the security descriptor to retrieve. 
    ///                      Defaults to all members except the SACL.
    @concurrent
    public func securityInfo(
        _ members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl
    ) async throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.securityInfo(members)
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    /// Updates the Windows security descriptor of the item referred by this handle.
    /// - Parameters:
    ///   - dacl: How to update the DACL. 
    ///           Can be replacing with a new DACL, removing it or leaving it unchanged.
    ///   - sacl: How to update the SACL.
    ///          Can be replacing with a new SACL, removing it or leaving it unchanged.
    ///   - owner: The new owner to set, or `nil` to leave unchanged.
    ///   - group: The new group to set, or `nil` to leave unchanged.
    /// 
    /// - Seealso: ``FileOperationOptions/WindowsAclUpdateRequest``
    @concurrent
    public func setSecurityInfo(
        dacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        sacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        owner: PlatformIdentity? = nil,
        group: PlatformIdentity? = nil
    ) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setSecurityInfo(dacl: dacl, sacl: sacl, owner: owner, group: group)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }
    #else

    /// Gets the POSIX permissions of the item referred by this handle.
    @concurrent
    public func posixPermissions() async throws(PlatformError) -> FilePermissions {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.posixPermissions()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    /// Updates the POSIX permissions of the item referred by this handle.
    /// - Parameter permissions: The new POSIX permissions to set.
    @concurrent
    public func setPosixPermissions(_ permissions: FilePermissions) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setPosixPermissions(permissions)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }

    #endif


    /// Gets the owner and group of the item referred by this handle.
    @concurrent
    public func owner() async throws(PlatformError) -> (owner: PlatformIdentity?, group: PlatformIdentity?) {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.owner()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    /// Updates the owner and group of the item referred by this handle.
    /// - Parameters:
    ///   - owner: The new owner to set, or `nil` to leave unchanged.
    ///   - group: The new group to set, or `nil` to leave unchanged.
    @concurrent
    public func setOwner(owner: PlatformIdentity?, group: PlatformIdentity?) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setOwner(owner: owner, group: group)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }

}
