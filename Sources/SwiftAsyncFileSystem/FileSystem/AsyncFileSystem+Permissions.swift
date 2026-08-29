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
        return try await executor.runCancellable(operation: .fetchMeta(path)) { () throws(PlatformError) in
            try fileSystem.canAccess(itemAt: path, for: accessMode, followSymlink: followSymlink)
        }
    }


    #if canImport(WinSDK)

    @concurrent
    public func getSecurityInfo(
        forItemAt path: FilePath,
        querying members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl,
        followSymlink: Bool = true
    ) async throws(PlatformError) -> sending WindowsSelfRelativeSecurityDescriptor {
        return try await executor.runCancellable(operation: .fetchMeta(path)) { () throws(PlatformError) in
            try fileSystem.getSecurityInfo(forItemAt: path, querying: members, followSymlink: followSymlink)
        }
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
        return try await executor.runCancellable(operation: .setMeta(path)) { () throws(PlatformError) in
            try fileSystem.setSecurityInfo(
                forItemAt: path,
                dacl: dacl,
                sacl: sacl,
                owner: owner,
                group: group,
                followSymlink: followSymlink
            )
        }
    }

    #else

    @concurrent
    public func getPosixPermissions(forItemAt path: FilePath, followSymlink: Bool = true) async throws(PlatformError) -> FilePermissions {
        return try await executor.runCancellable(operation: .fetchMeta(path)) { () throws(PlatformError) in
            try fileSystem.getPosixPermissions(forItemAt: path, followSymlink: followSymlink)
        }
    }


    @concurrent
    public func setPosixPermissions(forItemAt path: FilePath, permissions: FilePermissions, followSymlink: Bool = true) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .setMeta(path)) { () throws(PlatformError) in
            try fileSystem.setPosixPermissions(forItemAt: path, permissions: permissions, followSymlink: followSymlink)
        }
    }

    #endif


    @concurrent
    public func getOwner(
        forItemAt path: FilePath,
        followSymlink: Bool = true
    ) async throws(PlatformError) -> (owner: PlatformIdentity, group: PlatformIdentity) {
        return try await executor.runCancellable(operation: .fetchMeta(path)) { () throws(PlatformError) in
            try fileSystem.getOwner(forItemAt: path, followSymlink: followSymlink)
        }
    }


    @concurrent
    public func setOwner(
        forItemAt path: FilePath,
        owner: PlatformIdentity?,
        group: PlatformIdentity?,
        followSymlink: Bool = true
    ) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .setMeta(path)) { () throws(PlatformError) in
            try fileSystem.setOwner(forItemAt: path, owner: owner, group: group, followSymlink: followSymlink)
        }
    }

}
