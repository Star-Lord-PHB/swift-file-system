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

    @concurrent
    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> sending R
    ) async throws(E) -> sending R


}



extension SystemHandleSupportedAsyncFileHandleProtocol where Self: ~Copyable & ~Escapable & ExecutorSupportedAsyncFileHandleProtocol {

    @concurrent
    public func withUnsafeSystemHandleInExecutor<R: ~Copyable, E: Error>(
        _ task: (borrowing UnsafeSystemHandle) throws(E) -> sending R
    ) async -> sending AsyncFileSystemExecutor.Result<R, E> {
        await self.withUnsafeSystemHandle { handle in
            await executor.runCancellable { () throws(E) in
                try task(handle)
            }
        }
    }


    @concurrent
    func withUnsafeSystemHandleInExecutor<R: ~Copyable>(
        operation: PlatformError.Operation,
        _ task: (borrowing UnsafeSystemHandle) throws(PlatformError) -> sending R
    ) async throws(PlatformError) -> sending R {
        try await self.withUnsafeSystemHandleInExecutor { handle throws(PlatformError) in
            try task(handle)
        }
        .getThrowingPlatformError(operation: operation)
    }


    @concurrent
    func withUnsafeSystemHandleInExecutor<R: ~Copyable>(
        operation: PlatformError.Operation,
        _ task: (borrowing UnsafeSystemHandle) throws(LowLevelError) -> sending R
    ) async throws(PlatformError) -> sending R {
        try await self.withUnsafeSystemHandleInExecutor { handle throws(LowLevelError) in
            try task(handle)
        }
        .getThrowingPlatformError(operation: operation)
    }


}



public typealias AutoSynthesisAsyncFileHandleProtocol
    = ExecutorSupportedAsyncFileHandleProtocol & SystemHandleSupportedAsyncFileHandleProtocol



extension AsyncFileHandleProtocol where Self: ~Copyable & ~Escapable & AutoSynthesisAsyncFileHandleProtocol {

    @concurrent
    func withSyncHandleViewInExecutor<R: ~Copyable>(
        operation: PlatformError.Operation,
        _ task: (borrowing SyncHandleView) throws(PlatformError) -> sending R
    ) async throws(PlatformError) -> sending R {
        let path = self.path
        return try await withUnsafeSystemHandleInExecutor(operation: operation) { (sysHandle) throws(PlatformError) in
            try task(SyncHandleView(systemHandle: sysHandle, path: path))
        }
    }


    @concurrent
    public func fileInfo() async throws(PlatformError) -> FileInfo {
        return try await withSyncHandleViewInExecutor(operation: .fetchMeta(path)) { (view) throws(PlatformError) in
            try view.fileInfo()
        }
    }


    @concurrent
    public func type() async throws(PlatformError) -> FileKind {
        return try await withSyncHandleViewInExecutor(operation: .fetchMeta(path)) { (view) throws(PlatformError) in
            try view.type()
        }
    }


    @concurrent
    public func fileTimes() async throws(PlatformError) -> FileTimes {
        return try await withSyncHandleViewInExecutor(operation: .fetchMeta(path)) { (view) throws(PlatformError) in
            try view.fileTimes()
        }
    }


    @concurrent
    public func setFileTimes(
        access: FileTimeSpec? = nil,
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) async throws(PlatformError) {
        return try await withSyncHandleViewInExecutor(operation: .setMeta(path)) { (view) throws(PlatformError) in
            try view.setFileTimes(access: access, modification: modification, creation: creation)
        }
    }


    @concurrent
    public func fileAttributes() async throws(PlatformError) -> PlatformFileAttributes {
        return try await withSyncHandleViewInExecutor(operation: .fetchMeta(path)) { (view) throws(PlatformError) in
            try view.fileAttributes()
        }
    }


    @concurrent
    public func setFileAttributes(_ attributes: PlatformFileAttributes) async throws(PlatformError) {
        return try await withSyncHandleViewInExecutor(operation: .setMeta(path)) { (view) throws(PlatformError) in
            try view.setFileAttributes(attributes)
        }
    }


    #if canImport(Glibc) || canImport(Musl)

    @concurrent
    public func inodeFlags() async throws(PlatformError) -> LinuxInodeFlags {
        return try await withSyncHandleViewInExecutor(operation: .fetchMeta(path)) { (view) throws(PlatformError) in
            try view.inodeFlags()
        }
    }


    @concurrent
    public func setInodeFlags(_ flags: LinuxInodeFlags) async throws(PlatformError) {
        return try await withSyncHandleViewInExecutor(operation: .setMeta(path)) { (view) throws(PlatformError) in
            try view.setInodeFlags(flags)
        }
    }

    #endif


    #if canImport(WinSDK)

    @concurrent
    public func securityInfo(
        _ members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl
    ) async throws(PlatformError) -> sending WindowsSelfRelativeSecurityDescriptor {
        return try await withSyncHandleViewInExecutor(operation: .fetchMeta(path)) { (view) throws(PlatformError) in
            try view.securityInfo(members)
        }
    }


    @concurrent
    public func setSecurityInfo(
        dacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        sacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        owner: PlatformIdentity? = nil,
        group: PlatformIdentity? = nil
    ) async throws(PlatformError) {
        return try await withSyncHandleViewInExecutor(operation: .setMeta(path)) { (view) throws(PlatformError) in
            try view.setSecurityInfo(dacl: dacl, sacl: sacl, owner: owner, group: group)
        }
    }

    #else

    @concurrent
    public func posixPermissions() async throws(PlatformError) -> FilePermissions {
        return try await withSyncHandleViewInExecutor(operation: .fetchMeta(path)) { (view) throws(PlatformError) in
            try view.posixPermissions()
        }
    }


    @concurrent
    public func setPosixPermissions(_ permissions: FilePermissions) async throws(PlatformError) {
        return try await withSyncHandleViewInExecutor(operation: .setMeta(path)) { (view) throws(PlatformError) in
            try view.setPosixPermissions(permissions)
        }
    }

    #endif


    @concurrent
    public func owner() async throws(PlatformError) -> (owner: PlatformIdentity?, group: PlatformIdentity?) {
        return try await withSyncHandleViewInExecutor(operation: .fetchMeta(path)) { (view) throws(PlatformError) in
            try view.owner()
        }
    }


    @concurrent
    public func setOwner(owner: PlatformIdentity?, group: PlatformIdentity?) async throws(PlatformError) {
        return try await withSyncHandleViewInExecutor(operation: .setMeta(path)) { (view) throws(PlatformError) in
            try view.setOwner(owner: owner, group: group)
        }
    }

}
