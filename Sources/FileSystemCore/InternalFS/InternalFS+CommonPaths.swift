import PlatformCLib
import SystemPackage

#if canImport(MachO.dyld)
import MachO.dyld
#endif



extension InternalFS {

    package static func currentWorkingDirectoryPath() throws(LowLevelError) -> FilePath {

        #if canImport(WinSDK)

        var buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(MAX_PATH))
        defer { buffer.deallocate() }

        SetLastError(0)

        let requiredSize = PlatformCLib.GetCurrentDirectoryW(DWORD(MAX_PATH), buffer)

        guard requiredSize > 0 else {
            try LowLevelError.assertError(fallbackToUnknownError: true)
        }

        if requiredSize <= DWORD(MAX_PATH) {
            return .init(platformString: buffer)
        }

        buffer.deallocate()
        buffer = .allocate(capacity: Int(requiredSize))

        SetLastError(0)

        guard PlatformCLib.GetCurrentDirectoryW(requiredSize, buffer) != 0 else {
            try LowLevelError.assertError(fallbackToUnknownError: true)
        }

        return .init(platformString: buffer)

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
                throw LowLevelError(rawSystemCode: errorCode)!
            }
        }

        return .init(platformString: buffer.baseAddress!)

        #endif

    }


    package static func tmpDirectoryPath() throws(LowLevelError) -> FilePath {

        #if canImport(WinSDK)

        var buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(MAX_PATH + 1))
        defer { buffer.deallocate() }

        let requiredSize = PlatformCLib.GetTempPathW(DWORD(MAX_PATH + 1), buffer)
        guard requiredSize > 0 else {
            try LowLevelError.assertError(fallbackToUnknownError: true)
        }

        if requiredSize <= DWORD(MAX_PATH + 1) {
            return .init(platformString: buffer)
        }

        buffer.deallocate()
        buffer = .allocate(capacity: Int(requiredSize))

        guard PlatformCLib.GetTempPathW(requiredSize, buffer) != 0 else {
            try LowLevelError.assertError(fallbackToUnknownError: true)
        }

        return .init(platformString: buffer)

        #elseif canImport(Darwin)

        errno = 0
        let sizeNeeded = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        guard sizeNeeded > 0 else {
            try LowLevelError.assertError(fallbackToUnknownError: true)
        }

        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: sizeNeeded)
        defer { buffer.deallocate() }

        guard confstr(_CS_DARWIN_USER_TEMP_DIR, buffer, sizeNeeded) > 0 else {
            try LowLevelError.assertError(fallbackToUnknownError: true)
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
            #if os(Android)
            // Android has no /tmp; like Foundation, fall back to the directory Bionic uses.
            return .init("/data/local/tmp")
            #else
            return .init("/tmp")
            #endif
        }

        #endif 

    }


    package static func homeDirectoryPath() throws(LowLevelError) -> FilePath {

        #if canImport(WinSDK)

        let tokenHandle = try WindowsProcessToken.current()

        var pathBufferSize = DWORD(MAX_PATH)
        var pathBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(pathBufferSize))

        if GetUserProfileDirectoryW(tokenHandle.handle.unsafeResourcePtr, pathBuffer, &pathBufferSize) {
            return .init(platformString: pathBuffer)
        }

        let error = GetLastError()
        if error != ERROR_INSUFFICIENT_BUFFER {
            throw .init(rawSystemCode: error)!
        }

        pathBuffer.deallocate()
        pathBuffer = .allocate(capacity: Int(pathBufferSize))

        try execThrowingCFunction {
            GetUserProfileDirectoryW(tokenHandle.handle.unsafeResourcePtr, pathBuffer, &pathBufferSize)
        }

        return .init(platformString: pathBuffer)

        #else

        #if canImport(Darwin)
        // As with Foundation, CFFIXED_USER_HOME relocates the home ahead of the account database
        // (except in setuid/setgid processes), and HOME is not consulted.
        if issetugid() == 0, let fixedHome = getenv("CFFIXED_USER_HOME") {
            let path = FilePath(platformString: fixedHome)
            if path.isAbsolute { return path }
        }
        #else
        // As with most Unix tools and the XDG base directories, HOME takes precedence over the
        // account database.
        if let home = getenv("HOME") {
            let path = FilePath(platformString: home)
            if path.isAbsolute { return path }
        }
        #endif

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

            throw LowLevelError(rawSystemCode: error)!

        }

        guard result != nil, let homeDirectory = pwd.pw_dir else { throw .unknown }

        return .init(platformString: homeDirectory)
        
        #endif 

    }


    package static func executablePath() throws(LowLevelError) -> FilePath {

        #if canImport(WinSDK)

        var bufferSize = DWORD(MAX_PATH)
        var buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(bufferSize))
        defer { buffer.deallocate() }

        while true {
            let length = GetModuleFileNameW(nil, buffer, bufferSize)
            guard length > 0 else {
                try LowLevelError.assertError(fallbackToUnknownError: true)
            }
            if length < bufferSize {
                return .init(platformString: buffer)
            }
            bufferSize *= 2
            buffer.deallocate()
            buffer = .allocate(capacity: Int(bufferSize))
        }

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
            // This function should only fail when the buffer size is not large enough
            throw .unknown
        }

        return try realpath(of: .init(platformString: buffer))

        #else 

        try readlink(fromSymlinkAt: "/proc/self/exe")

        #endif

    }


    package static func cacheDirectoryPath() throws(LowLevelError) -> FilePath {

        #if canImport(WinSDK)

        do {

            // On Windows, we are currently using the %LOCALAPPDATA% path (default to %USERPROFILE%\AppData\Local)
            // as the cache directory. This is not the same as what provided by Foundation FileManager, which uses
            // %LOCALAPPDATA%/Temp, but matches closer to the original definition of %LOCALAPPDATA%.

            var pathBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(MAX_PATH))
            defer { pathBuffer.deallocate() }

            let lengthRequired = "LOCALAPPDATA".withCString(encodedAs: UTF16.self) { varNamePtr in
                GetEnvironmentVariableW(varNamePtr, pathBuffer, DWORD(MAX_PATH))
            }

            guard lengthRequired > 0 else {
                try LowLevelError.assertError(fallbackToUnknownError: true)
            }

            if lengthRequired < DWORD(MAX_PATH) {
                return .init(platformString: pathBuffer)
            }

            pathBuffer.deallocate()
            pathBuffer = .allocate(capacity: Int(lengthRequired))

            let length = "LOCALAPPDATA".withCString(encodedAs: UTF16.self) { varNamePtr in
                GetEnvironmentVariableW(varNamePtr, pathBuffer, lengthRequired)
            }

            guard length > 0 && length < lengthRequired else {
                try LowLevelError.assertError(fallbackToUnknownError: true)
            }

            return .init(platformString: pathBuffer)

        } catch where error.systemCode?.rawValue == DWORD(ERROR_ENVVAR_NOT_FOUND) {
            return try homeDirectoryPath().appending("AppData").appending("Local")
        }

        #elseif canImport(Darwin)

        return try homeDirectoryPath().appending("Library").appending("Caches")

        #else 

        // The XDG Base Directory Specification requires a relative XDG_CACHE_HOME to be ignored.
        if let xdgCache = getenv("XDG_CACHE_HOME") {
            let path = FilePath(platformString: xdgCache)
            if path.isAbsolute { return path }
        }
        return try homeDirectoryPath().appending(".cache")

        #endif

    }

}
