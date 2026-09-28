//
//  AsyncFileSystem+Permissions.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/28.
//

import SwiftFileSystem


extension AsyncFileSystem {

    @concurrent
    public func canAccess(
        itemAt path: FilePath,
        for accessMode: FileOperationOptions.FileAccessMode = [.read, .write],
        followSymlink: Bool = true
    ) async throws(PlatformError) -> Bool {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.canAccess(itemAt: path, for: accessMode, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .fetchMeta(path))
    }


    #if canImport(WinSDK)

    @concurrent
    public func securityInfo(
        ofItemAt path: FilePath,
        querying members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl,
        followSymlink: Bool = true
    ) async throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.securityInfo(ofItemAt: path, querying: members, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setSecurityInfo(
        forItemAt path: FilePath,
        dacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        sacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        owner: PlatformIdentity? = nil,
        group: PlatformIdentity? = nil,
        followSymlink: Bool = true
    ) async throws(PlatformError) {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.setSecurityInfo(
                forItemAt: path,
                dacl: dacl,
                sacl: sacl,
                owner: owner,
                group: group,
                followSymlink: followSymlink
            )
        }.getThrowingPlatformError(operation: .setMeta(path))
    }

    #else

    @concurrent
    public func posixPermissions(ofItemAt path: FilePath, followSymlink: Bool = true) async throws(PlatformError) -> FilePermissions {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.posixPermissions(ofItemAt: path, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setPosixPermissions(forItemAt path: FilePath, permissions: FilePermissions, followSymlink: Bool = true) async throws(PlatformError) {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.setPosixPermissions(forItemAt: path, permissions: permissions, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .setMeta(path))
    }

    #endif


    @concurrent
    public func owner(
        ofItemAt path: FilePath,
        followSymlink: Bool = true
    ) async throws(PlatformError) -> (owner: PlatformIdentity, group: PlatformIdentity) {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.owner(ofItemAt: path, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setOwner(
        forItemAt path: FilePath,
        owner: PlatformIdentity?,
        group: PlatformIdentity?,
        followSymlink: Bool = true
    ) async throws(PlatformError) {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.setOwner(forItemAt: path, owner: owner, group: group, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .setMeta(path))
    }

}
