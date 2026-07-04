import SystemPackage
import FileSystemCore


extension FileSystem {

    public func currentWorkingDirectoryPath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryCurrentWorkingDir) { () throws(SystemError) in
            try InternalFS.currentWorkingDirectoryPath()
        }
    }


    public func executablePath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryExecutablePath) { () throws(SystemError) in
            try InternalFS.executablePath()
        }
    }


    public func tempDirectoryPath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryTempDir) { () throws(SystemError) in
            try InternalFS.tmpDirectoryPath()
        }
    }


    public func homeDirectoryPath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryHomeDir) { () throws(SystemError) in
            try InternalFS.homeDirectoryPath()
        }
    }


    public func cacheDirectoryPath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryCacheDir) { () throws(SystemError) in
            try InternalFS.cacheDirectoryPath()
        }
    }

}
