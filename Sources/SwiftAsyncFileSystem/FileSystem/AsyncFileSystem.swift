//
//  AsyncFileSystem.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/28.
//

import SwiftFileSystem


/// Path-based async file-system operations, implemented by dispatching the synchronous
/// `FileSystem` onto an `AsyncFileSystemExecutor`.
///
/// The executor must have been started before any operation runs. Values of this type are
/// cheap to copy and share; all state lives in the executor.
public struct AsyncFileSystem: AsyncFileSystemProtocol {

    public let executor: AsyncFileSystemExecutor
    public let fileSystem: FileSystem


    public init(executor: AsyncFileSystemExecutor, fileSystem: FileSystem = .init()) {
        self.executor = executor
        self.fileSystem = fileSystem
    }

}



extension AsyncFileSystem {

    @concurrent
    public func itemExists(at path: FilePath, followSymlinks: Bool = true) async -> Bool {
        return await executor.run {
            fileSystem.itemExists(at: path, followSymlinks: followSymlinks)
        }
    }


    @concurrent
    public func createFile(
        at path: FilePath,
        replaceExisting: Bool = false,
        permissions: FilePermissions? = nil,
        content: ByteBuffer? = nil
    ) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .createFile(path)) { () throws(PlatformError) in
            try fileSystem.createFile(at: path, replaceExisting: replaceExisting, permissions: permissions, content: content)
        }
    }


    @concurrent
    public func createDirectory(
        at path: FilePath,
        withIntermediateDirectories: Bool = false,
        permissions: FilePermissions? = nil
    ) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .createDirectory(path)) { () throws(PlatformError) in
            try fileSystem.createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, permissions: permissions)
        }
    }


    #if canImport(WinSDK)

    @concurrent
    public func createFile(
        at path: FilePath,
        replaceExisting: Bool = false,
        permissions: WindowsSecurityDescriptorView,
        content: ByteBuffer? = nil
    ) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .createFile(path)) { () throws(PlatformError) in
            try fileSystem.createFile(at: path, replaceExisting: replaceExisting, permissions: permissions, content: content)
        }
    }


    @concurrent
    public func createDirectory(
        at path: FilePath,
        withIntermediateDirectories: Bool = false,
        permissions: WindowsSecurityDescriptorView
    ) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .createDirectory(path)) { () throws(PlatformError) in
            try fileSystem.createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, permissions: permissions)
        }
    }

    #endif


    @concurrent
    public func moveItem(
        at srcPath: FilePath,
        to dstPath: FilePath,
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption = .overwrite
    ) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .move(srcPath: srcPath, dstPath: dstPath)) { () throws(PlatformError) in
            try fileSystem.moveItem(at: srcPath, to: dstPath, onExistingTarget: targetExistOption)
        }
    }


    @concurrent
    public func contentsOfDirectory(
        at path: FilePath,
        options: FileOperationOptions.DirectoryTraversalOption = []
    ) async throws(PlatformError) -> [DirectoryEntry] {
        return try await executor.runCancellable(operation: .readDirectory(path)) { () throws(PlatformError) in
            try fileSystem.contentsOfDirectory(at: path, options: options)
        }
    }


    @concurrent
    public func createSymLink(at path: FilePath, pointingTo destPath: FilePath) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .createSymlink(linkPath: path, dstPath: destPath)) { () throws(PlatformError) in
            try fileSystem.createSymLink(at: path, pointingTo: destPath)
        }
    }


    @concurrent
    public func createHardLink(at path: FilePath, for existingPath: FilePath) async throws(PlatformError) {
        return try await executor.runCancellable(operation: .createHardLink(linkPath: path, existingPath: existingPath)) { () throws(PlatformError) in
            try fileSystem.createHardLink(at: path, for: existingPath)
        }
    }


    @concurrent
    public func destinationOfSymLink(at path: FilePath, recursive: Bool = true) async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable(
            operation: recursive ? .recursiveResolveSymlink(path) : .readSymlink(path)
        ) { () throws(PlatformError) in
            try fileSystem.destinationOfSymLink(at: path, recursive: recursive)
        }
    }

}
