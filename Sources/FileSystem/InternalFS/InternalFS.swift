import PlatformCLib
import CFileSystem
import SystemPackage



@usableFromInline
enum InternalFS {

    static func rename(itemAt srcPath: FilePath, to dstPath: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    renameat(AT_FDCWD, srcPtr, AT_FDCWD, dstPtr)
                }
            }
        }

        #endif 

    }


    static func copyRegularFile(from srcHandle: borrowing UnsafeSystemHandle, to dstHandle: borrowing UnsafeSystemHandle, _ srcFileSize: UInt64? = nil) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #elseif canImport(Darwin)

        try execThrowingCFunction {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_ALL))
        }

        #else 

        var srcOffset: off_t = 0
        var dstOffset: off_t = 0
        var fallbackToManualCopy = false

        while true {
            // faster path using copy_file_range if available

            let byteCopied = copy_file_range(srcHandle.unsafeRawHandle, &srcOffset, dstHandle.unsafeRawHandle, &dstOffset, .init(srcFileSize ?? 0x7ffff000), 0)
            if byteCopied < 0 && errno == ENOSYS {
                // copy_file_range not available, fallback to manual copy
                fallbackToManualCopy = true
                break
            }
            // EINTR (interrupted) can be ignored and simply retry
            guard byteCopied >= 0 || errno != EINTR else {
                try SystemError.assertError()
            }
            guard byteCopied > 0 else { break }

        }

        if fallbackToManualCopy {

            var buffer = ByteBuffer(count: 64 * 1024)

            while true {
                // manual copy, only used when copy_file_range is not available

                let bytesRead = try buffer.withUnsafeMutableBytes { (ptr) throws(SystemError) in
                    try srcHandle.read(into: ptr)
                }
                guard bytesRead > 0 else { break }

                try buffer.withUnsafeBytes { (ptr) throws(SystemError) in
                    _ = try dstHandle.write(contentsOf: ptr)
                }

                if bytesRead < buffer.count { break }

            }

        }

        #endif 

    }


    static func makeRandomTmpName(in dirPath: FilePath, prefix: FilePath.Component) -> FilePath {

        #if canImport(WinSDK)
        let pid = GetCurrentProcessId()
        #else 
        let pid = getpid()
        #endif
        let lastComponent = FilePath.Component("\(prefix).tmp-\(pid)-\(String(UInt64.random(in: 0 ... .max), radix: 16))")!
        return dirPath.appending(lastComponent)

    }


    static func makeRandomTmpName(baseOn path: FilePath) -> FilePath {
        assert(path.lastComponent != nil, "base path for temp file name must not be empty")
        return makeRandomTmpName(in: path.removingLastComponent(), prefix: path.lastComponent!)
    }


    struct TmpFileResult: ~Copyable {
        let path: FilePath
        let handle: UnsafeSystemHandle
        consuming func takeHandle() -> UnsafeSystemHandle {
            return handle
        }
    }


    static func makeTmpFile(in dirPath: FilePath, prefix: FilePath.Component) throws(SystemError) -> TmpFileResult {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        var pathBuffer = (dirPath.string + "/\(prefix).tmp-XXXXXX").utf8CString

        let fd = pathBuffer.withUnsafeMutableBufferPointer { strPtr in 
            mkstemp(strPtr.baseAddress!)
        }

        guard fd >= 0 else {
            try SystemError.assertError()
        }

        let tmpPath = pathBuffer.withUnsafeBufferPointer { FilePath(platformString: $0.baseAddress!) }

        return .init(path: tmpPath, handle: .init(owningRawHandle: fd))

        #endif 

    }


    static func makeTmpFile(baseOn path: FilePath) throws(SystemError) -> TmpFileResult {

        assert(path.lastComponent != nil, "base path for temp file must not be empty")
        return try makeTmpFile(in: path.removingLastComponent(), prefix: path.lastComponent!)

    }


    static func readlink(fromSymlinkAt linkPath: FilePath) throws(SystemError) -> FilePath {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        var buffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: Int(max(PATH_MAX, 1024)))
        defer { buffer.deallocate() }

        while true {
            let len = linkPath.withPlatformString { strPtr in 
                PlatformCLib.readlink(strPtr, buffer.baseAddress!, buffer.count - 1)
            }
            if len < 0 {
                try SystemError.assertError()
            } else if len == buffer.count - 1 {
                let newBuffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: buffer.count * 2)
                _ = newBuffer.moveInitialize(fromContentsOf: buffer)
                buffer.deallocate()
                buffer = newBuffer
            } else {
                buffer[len] = 0
                break
            }
        }

        return .init(platformString: buffer.baseAddress!)

        #endif

    }


    static func realpath(of path: FilePath) throws(SystemError) -> FilePath {

        #if canImport(WinSDK)
        #warning("Not implemented")
        fatalError("Not implemented")
        #else

        let buffer = path.withPlatformString { strPtr in 
            PlatformCLib.realpath(strPtr, nil)
        }
        guard let buffer else {
            try SystemError.assertError()
        }

        defer { free(buffer) }

        return .init(platformString: buffer)

        #endif 

    }


    static func unlink(fileAt path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                PlatformCLib.unlink(pathPtr)
            }
        }

        #endif

    }


    static func rmdir(at path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                PlatformCLib.rmdir(pathPtr)
            }
        }

        #endif

    }


    static func remove(itemAt path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                PlatformCLib.remove(pathPtr)
            }
        }

        #endif

    }


    static func mkdir(at path: FilePath, permissions: FilePermissions?) throws(SystemError) {

        #if canImport(WinSDK)

        // TODO: On Windows, try to map posix permission to Windows ACL Permissions

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                PlatformCLib.mkdir(pathPtr, (permissions ?? [.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute]).rawValue)
            }
        }

        #endif

    }


    #if canImport(WinSDK)
    // TODO: use Windows ACL Permissions
    static func mkdir(at path: FilePath, /* permission: SomeWindowsACLPermissionsType */) throws(SystemError) {
        #warning("Not implemented")
        fatalError("Not implemented")
    }
    #endif 


    static func symlink(dstPath: FilePath, linkPath: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            linkPath.withPlatformString { linkPtr in 
                dstPath.withPlatformString { dstPtr in 
                    PlatformCLib.symlink(dstPtr, linkPtr)
                }
            }
        }

        #endif

    }


    static func link(existingPath: FilePath, newPath: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            existingPath.withPlatformString { existingPtr in 
                newPath.withPlatformString { newPtr in 
                    PlatformCLib.linkat(AT_FDCWD, existingPtr, AT_FDCWD, newPtr, 0)
                }
            }
        }

        #endif

    }


    #if canImport(WinSDK)
    // MARK: TODO: add setting file times for Windows
    #else 

    static func utimens(for path: FilePath, times: (timespec, timespec)) throws(SystemError) {
        try execThrowingCFunction {
            withUnsafePointer(to: times) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    path.withPlatformString { pathPtr in 
                        utimensat(AT_FDCWD, pathPtr, reboundPtr, AT_SYMLINK_NOFOLLOW)
                    }
                }
            }
        }
    }


    static func futimens(for handle: borrowing UnsafeSystemHandle, times: (timespec, timespec)) throws(SystemError) {
        try execThrowingCFunction {
            withUnsafePointer(to: times) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    PlatformCLib.futimens(handle.unsafeRawHandle, reboundPtr)
                }
            }
        }
    }

    #endif

}