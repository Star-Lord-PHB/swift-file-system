//
//  AsyncFileSystem+FileInfo.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/28.
//

import SwiftFileSystem


extension AsyncFileSystem {

    @concurrent
    public func info(ofItemAt path: FilePath, followSymlinks: Bool = true) async throws(PlatformError) -> FileInfo {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.info(ofItemAt: path, followSymlinks: followSymlinks)
        }.getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setTimes(
        forItemAt path: FilePath,
        accessTime: FileTimeSpec? = nil,
        modificationTime: FileTimeSpec? = nil,
        creationTime: FileTimeSpec? = nil,
        followSymlink: Bool = true
    ) async throws(PlatformError) {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.setTimes(
                forItemAt: path,
                accessTime: accessTime,
                modificationTime: modificationTime,
                creationTime: creationTime,
                followSymlink: followSymlink
            )
        }.getThrowingPlatformError(operation: .setMeta(path))
    }


    @concurrent
    public func setAttributes(
        forItemAt path: FilePath,
        attributes: PlatformFileAttributes,
        followSymlink: Bool = true
    ) async throws(PlatformError) {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.setAttributes(forItemAt: path, attributes: attributes, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .setMeta(path))
    }


    #if canImport(Glibc) || canImport(Musl)

    @concurrent
    public func getInodeFlags(forItemAt path: FilePath, followSymlink: Bool = true) async throws(PlatformError) -> LinuxInodeFlags {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.getInodeFlags(forItemAt: path, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .fetchMeta(path))
    }


    @concurrent
    public func setInodeFlags(forItemAt path: FilePath, flags: LinuxInodeFlags, followSymlink: Bool = true) async throws(PlatformError) {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.setInodeFlags(forItemAt: path, flags: flags, followSymlink: followSymlink)
        }.getThrowingPlatformError(operation: .setMeta(path))
    }

    #endif

}
