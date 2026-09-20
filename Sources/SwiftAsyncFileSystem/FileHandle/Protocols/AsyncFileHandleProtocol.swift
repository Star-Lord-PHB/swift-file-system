//
//  AsyncFileHandleProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/29.
//

import SwiftFileSystem


/// Root of the async handle family.
///
/// Operations are `@concurrent` and observe task cancellation before the blocking work
/// starts (surfaced as a `PlatformError` with kind `.cancelled` and the body never run);
/// once started, an operation always runs to completion.
public protocol AsyncFileHandleProtocol: ~Copyable, ~Escapable {
    var path: FilePath { get }
}



public protocol ExecutorSupportedAsyncFileHandleProtocol: ~Copyable, ~Escapable {
    var executor: AsyncFileSystemExecutor { get }
}



public protocol SystemHandleSupportedAsyncFileHandleProtocol: ~Copyable, ~Escapable {

    var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get
    }

}



extension SystemHandleSupportedAsyncFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> R
    ) async throws(E) -> R {
        try await unsafeHandleContext.withUnsafeSystemHandle(operation)
    }

}



public protocol AutoSynthesisAsyncFileHandleProtocol
: ~Copyable, ~Escapable
, ExecutorSupportedAsyncFileHandleProtocol, SystemHandleSupportedAsyncFileHandleProtocol {}



extension AutoSynthesisAsyncFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @concurrent
    public func withUnsafeHandleContextInExecutor<R: ~Copyable, E: Error>(
        _ operation: (UnsafeHandleContextView) throws(E) -> R
    ) async -> AsyncFileSystemExecutor.Result<R, E> {
        await executor.runCancellable { () throws(E) in
            try operation(unsafeHandleContext)
        }
    }


    @concurrent
    public func withUnsafeSystemHandleInExecutor<R: ~Copyable, E: Error>(
        _ task: (borrowing UnsafeSystemHandle) throws(E) -> R
    ) async -> AsyncFileSystemExecutor.Result<R, E> {
        await self.withUnsafeSystemHandle { handle in
            await executor.runCancellable { () throws(E) in
                try task(handle)
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


    @concurrent
    public func fileInfo() async throws(PlatformError) -> FileInfo {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.fileInfo()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func type() async throws(PlatformError) -> FileKind {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.type()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func fileTimes() async throws(PlatformError) -> FileTimes {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.fileTimes()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


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


    @concurrent
    public func fileAttributes() async throws(PlatformError) -> PlatformFileAttributes {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.fileAttributes()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setFileAttributes(_ attributes: PlatformFileAttributes) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setFileAttributes(attributes)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }


    #if os(Linux) || os(Android)

    @concurrent
    public func inodeFlags() async throws(PlatformError) -> LinuxInodeFlags {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.inodeFlags()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setInodeFlags(_ flags: LinuxInodeFlags) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setInodeFlags(flags)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }

    #endif


    #if canImport(WinSDK)

    @concurrent
    public func securityInfo(
        _ members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl
    ) async throws(PlatformError) -> sending WindowsSelfRelativeSecurityDescriptor {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try SendableBox(adapter.securityInfo(members))
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
        .take()
    }


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

    @concurrent
    public func posixPermissions() async throws(PlatformError) -> FilePermissions {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.posixPermissions()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setPosixPermissions(_ permissions: FilePermissions) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setPosixPermissions(permissions)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }

    #endif


    @concurrent
    public func owner() async throws(PlatformError) -> (owner: PlatformIdentity?, group: PlatformIdentity?) {
        return try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.owner()
        }
        .getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setOwner(owner: PlatformIdentity?, group: PlatformIdentity?) async throws(PlatformError) {
        try await withSyncHandleAdapterInExecutor { (adapter) throws(PlatformError) in
            try adapter.setOwner(owner: owner, group: group)
        }
        .getThrowingPlatformError(operation: .setMeta(path))
    }

}
