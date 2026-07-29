import SystemPackage
import FileSystemCore


extension FileSystem {

    public func currentWorkingDirectoryPath() throws(PlatformError) -> FilePath {
        try catchLowLevelError(operation: .queryCurrentWorkingDir) { () throws(LowLevelError) in
            try InternalFS.currentWorkingDirectoryPath()
        }
    }


    public func executablePath() throws(PlatformError) -> FilePath {
        try catchLowLevelError(operation: .queryExecutablePath) { () throws(LowLevelError) in
            try InternalFS.executablePath()
        }
    }


    public func tempDirectoryPath() throws(PlatformError) -> FilePath {
        try catchLowLevelError(operation: .queryTempDir) { () throws(LowLevelError) in
            try InternalFS.tmpDirectoryPath()
        }
    }


    public func homeDirectoryPath() throws(PlatformError) -> FilePath {
        try catchLowLevelError(operation: .queryHomeDir) { () throws(LowLevelError) in
            try InternalFS.homeDirectoryPath()
        }
    }


    public func cacheDirectoryPath() throws(PlatformError) -> FilePath {
        try catchLowLevelError(operation: .queryCacheDir) { () throws(LowLevelError) in
            try InternalFS.cacheDirectoryPath()
        }
    }

}
