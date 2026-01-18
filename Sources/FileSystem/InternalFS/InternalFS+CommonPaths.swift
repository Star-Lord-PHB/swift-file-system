import PlatformCLib
import struct SystemPackage.FilePath

#if canImport(MachO.dyld)
import MachO.dyld
#endif



extension InternalFS {

    static func currentWorkingDirectoryPath() throws(SystemError) -> FilePath {

        #if canImport(WinSDK)

        throw SystemError(code: .extended(.notImplemented))!
        #warning("Not yet implemented")

        #else 
        
        var buffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: max(Int(PATH_MAX), 1024))
        defer { buffer.deallocate() }

        while PlatformCLib.getcwd(buffer.baseAddress!, .init(buffer.count)) == nil {
            let errorCode = errno
            if errorCode == ERANGE {
                let newCount = buffer.count * 2
                buffer.deallocate()
                buffer = .allocate(capacity: newCount)
            } else {
                throw SystemError(code: errorCode)!
            }
        }

        return .init(platformString: buffer.baseAddress!)

        #endif

    }


    static func tmpDirectoryPath() throws(SystemError) -> FilePath {

        #if canImport(WinSDK)

        throw SystemError(code: .extended(.notImplemented))!
        #warning("Not yet implemented")

        #elseif canImport(Darwin)

        errno = 0
        let sizeNeeded = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        guard sizeNeeded > 0 else {
            try SystemError.assertError(fallbackToUnknownError: true)
        }

        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: sizeNeeded)
        defer { buffer.deallocate() }

        guard confstr(_CS_DARWIN_USER_TEMP_DIR, buffer, sizeNeeded) > 0 else {
            try SystemError.assertError(fallbackToUnknownError: true)
        }

        return .init(platformString: buffer)

        #else

        if let tmpDir = getenv("TMPDIR") {
            return .init(platformString: tmpDir)
        } else if let tmpDir = getenv("TMP") {
            return .init(platformString: tmpDir)
        } else if let tmpDir = getenv("TEMP") {
            return .init(platformString: tmpDir)
        } else if let tmpDir = getenv("TEMPDIR") {
            return .init(platformString: tmpDir)
        } else {
            return .init("/tmp")
        }

        #endif 

    }


    static func homeDirectoryPath() throws(SystemError) -> FilePath {

        #if canImport(WinSDK)

        throw SystemError(code: .extended(.notImplemented))!
        #warning("Not yet implemented")

        #else 

        let currUid = getuid()

        var size = max(sysconf(Int32(_SC_GETPW_R_SIZE_MAX)), 1024)

        var pwd = passwd()
        var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
        defer { buffer.deallocate() }
        var result = nil as UnsafeMutablePointer<passwd>?

        while true {

            let error = getpwuid_r(currUid, &pwd, buffer, size, &result)

            if error == 0 { break }
            if error == ERANGE {
                size *= 2
                buffer.deallocate()
                buffer = .allocate(capacity: size)
                continue
            }

            throw SystemError(code: error)!

        }

        if result == nil { throw SystemError(code: .extended(.unknown))! }

        return .init(platformString: pwd.pw_dir)
        
        #endif 

    }


    static func executablePath() throws(SystemError) -> FilePath {

        #if canImport(WinSDK)

        throw SystemError(code: .extended(.notImplemented))!
        #warning("Not yet implemented")

        #elseif canImport(Darwin)

        var bufferSize = UInt32(PATH_MAX)
        var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(bufferSize))
        defer { buffer.deallocate() }

        if _NSGetExecutablePath(buffer, &bufferSize) == 0 {
            return .init(platformString: buffer)
        }

        buffer.deallocate()
        buffer = .allocate(capacity: Int(bufferSize))

        guard _NSGetExecutablePath(buffer, &bufferSize) == 0 else {
            throw SystemError(code: .extended(.unknown))!
        }

        return try realpath(of: .init(platformString: buffer))

        #else 

        try readlink(fromSymlinkAt: "/proc/self/exe")

        #endif

    }


    static func cacheDirectoryPath() throws(SystemError) -> FilePath {

        #if canImport(WinSDK)

        throw SystemError(code: .extended(.notImplemented))!
        #warning("Not yet implemented")

        #elseif canImport(Darwin)

        return try homeDirectoryPath().appending("Library").appending("Caches")

        #else 

        if let xdgCache = getenv("XDG_CACHE_HOME") {
            return .init(platformString: xdgCache)
        } else {
            return try homeDirectoryPath().appending(".cache")
        }

        #endif

    }

}