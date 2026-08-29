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
        return try await executor.runCancellable(operation: .queryCurrentWorkingDir) { () throws(PlatformError) in
            try fileSystem.currentWorkingDirectoryPath()
        }
    }


    @concurrent
    public func executablePath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable(operation: .queryExecutablePath) { () throws(PlatformError) in
            try fileSystem.executablePath()
        }
    }


    @concurrent
    public func homeDirectoryPath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable(operation: .queryHomeDir) { () throws(PlatformError) in
            try fileSystem.homeDirectoryPath()
        }
    }


    @concurrent
    public func tempDirectoryPath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable(operation: .queryTempDir) { () throws(PlatformError) in
            try fileSystem.tempDirectoryPath()
        }
    }


    @concurrent
    public func cacheDirectoryPath() async throws(PlatformError) -> FilePath {
        return try await executor.runCancellable(operation: .queryCacheDir) { () throws(PlatformError) in
            try fileSystem.cacheDirectoryPath()
        }
    }

}
