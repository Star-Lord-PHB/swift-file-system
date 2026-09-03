//
//  AsyncFileSystem+CommonPaths.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/28.
//

import SwiftFileSystem


extension AsyncFileSystem {

    @concurrent
    public func currentWorkingDirectoryPath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.currentWorkingDirectoryPath()
        }.getThrowingPlatformError(operation: .queryCurrentWorkingDir)
    }


    @concurrent
    public func executablePath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.executablePath()
        }.getThrowingPlatformError(operation: .queryExecutablePath)
    }


    @concurrent
    public func homeDirectoryPath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.homeDirectoryPath()
        }.getThrowingPlatformError(operation: .queryHomeDir)
    }


    @concurrent
    public func tempDirectoryPath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.tempDirectoryPath()
        }.getThrowingPlatformError(operation: .queryTempDir)
    }


    @concurrent
    public func cacheDirectoryPath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable { () throws(PlatformError) in
            try fileSystem.cacheDirectoryPath()
        }.getThrowingPlatformError(operation: .queryCacheDir)
    }

}
