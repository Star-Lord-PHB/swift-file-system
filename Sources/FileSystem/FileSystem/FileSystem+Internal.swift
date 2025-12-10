import SystemPackage
import PlatformCLib
import CFileSystem



extension FileSystem {

    // NOTE: Must fail if any item already exists
    func _createDirectoryNoIntermediate(at path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        try execThrowingCFunction {
            path.withPlatformString { platformStr in 
                CreateDirectoryW(platformStr, nil)
            }
        }

        #else 

        let permission = [.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute] as FilePermissions

        try execThrowingCFunction {
            mkdir(path.string, permission.rawValue)
        }

        #endif 

    }


    func _fastIsDir(at path: FilePath) throws(SystemError) -> Bool {

        #if canImport(WinSDK)

        let attributes = GetFileAttributesW(path.string.wideCString)
        guard attributes != INVALID_FILE_ATTRIBUTES else {
            try SystemError.assertError()
        }

        return (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0

        #else 

        var st = stat()
        try execThrowingCFunction {
            stat(path.string, &st)
        }

        return (st.st_mode & S_IFMT) == S_IFDIR

        #endif 

    }


    var platformItemAlreadyExistsErrorCode: FileError.PlatformErrorCode {
        #if canImport(WinSDK)
        .alreadyExists
        #else 
        .fileExists
        #endif
    }


    @inlinable
    func _symlinkDirectDestination(of path: FilePath) throws(SystemError) -> FilePath {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        var buffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: Int(max(PATH_MAX, 1024)))
        defer { buffer.deallocate() }

        while true {
            let len = path.withPlatformString { strPtr in 
                readlink(strPtr, buffer.baseAddress!, buffer.count - 1)
            }
            if len < 0 {
                try SystemError.assertError()
            } else if len == buffer.count - 1 {
                let newBuffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: buffer.count * 2)
                _ = newBuffer.initialize(fromContentsOf: buffer)
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


    func _symlinkRecursiveDestination(of path: FilePath) throws(SystemError) -> FilePath {

        #if canImport(WinSDK)
        #warning("Not implemented")
        fatalError("Not implemented")
        #else

        let buffer = path.withPlatformString { strPtr in 
            realpath(strPtr, nil)
        }
        guard let buffer else {
            try SystemError.assertError()
        }

        return .init(platformString: buffer)

        #endif 

    }


    func _removeDirectoryRecursive(at path: FilePath) throws(SystemError) {

        var enumerator = try DirectoryEntryRecursiveEnumerator(path: path, doStat: false)

        while let enumerationElement = try enumerator.next() {

            switch enumerationElement {
                case .entry(let entry) where entry.type != .directory && entry.path.lastComponent?.kind == .regular:
                    try _removeFile(at: path.appending(entry.path.components))
                case .leavingDir(let dirPath): 
                    try _removeEmptyDirectory(at: path.appending(dirPath.components))
                default:
                    break
            }

        }

        try _removeEmptyDirectory(at: path)

    }


    func _removeFile(at path: FilePath) throws(SystemError) {
        #if canImport(WinSDK)
        #warning("Not implemented")
        fatalError("Not implemented")
        #else
        try execThrowingCFunction {
            unlink(path.string)
        }
        #endif
    }


    func _removeEmptyDirectory(at path: FilePath) throws(SystemError) {
        #if canImport(WinSDK)
        #warning("Not implemented")
        fatalError("Not implemented")
        #else
        try execThrowingCFunction {
            rmdir(path.string)
        }
        #endif
    }

}



// MARK: Write File Infomation
extension FileSystem {

    func _writeFileTime(
        forItemAt path: FilePath, 
        access: FileInfo.PlatformTimeSpec, 
        modification: FileInfo.PlatformTimeSpec, 
        statusChange: FileInfo.PlatformTimeSpec, 
        creation: FileInfo.PlatformTimeSpec? = nil
    ) throws(SystemError) {
        try _writeFileTime(
            forItemAt: path, 
            access: access.platformFileTime, 
            modification: modification.platformFileTime, 
            statusChange: statusChange.platformFileTime, 
            creation: creation?.platformFileTime
        )
    }


    func _writeFileTime(
        for handle: borrowing UnsafeSystemHandle, 
        access: FileInfo.PlatformTimeSpec, 
        modification: FileInfo.PlatformTimeSpec, 
        statusChange: FileInfo.PlatformTimeSpec, 
        creation: FileInfo.PlatformTimeSpec? = nil
    ) throws(SystemError) {
        try _writeFileTime(
            for: handle, 
            access: access.platformFileTime, 
            modification: modification.platformFileTime, 
            statusChange: statusChange.platformFileTime, 
            creation: creation?.platformFileTime
        )
    }


    func _writeFileTime(
        forItemAt path: FilePath, 
        access: FileInfo.PlatformTimeSpec.PlatformFileTime, 
        modification: FileInfo.PlatformTimeSpec.PlatformFileTime, 
        statusChange: FileInfo.PlatformTimeSpec.PlatformFileTime, 
        creation: FileInfo.PlatformTimeSpec.PlatformFileTime? = nil
    ) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

        var times = (access, timespec())

        if let creation {
            times.1 = creation
            try execThrowingCFunction {
                withUnsafePointer(to: &times) { ptr in 
                    ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                        utimensat(AT_FDCWD, path.string, reboundPtr, AT_SYMLINK_NOFOLLOW)
                    }
                }
            }
        }

        times.1 = modification

        try execThrowingCFunction {
            withUnsafePointer(to: &times) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    utimensat(AT_FDCWD, path.string, reboundPtr, AT_SYMLINK_NOFOLLOW)
                }
            }
        }

        #else 

        var times = (access, modification)

        try execThrowingCFunction {
            withUnsafePointer(to: &times) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    utimensat(AT_FDCWD, path.string, reboundPtr, AT_SYMLINK_NOFOLLOW)
                }
            }
        }

        #endif 

    }


    // On windows, always single syscall
    // On bsd, status change time is not supported, single syscall if creation time is not provided, otherwise two syscalls
    // On other posix systems, creation time and status change time are not supported, always single syscall
    func _writeFileTime(
        for handle: borrowing UnsafeSystemHandle, 
        access: FileInfo.PlatformTimeSpec.PlatformFileTime, 
        modification: FileInfo.PlatformTimeSpec.PlatformFileTime, 
        statusChange: FileInfo.PlatformTimeSpec.PlatformFileTime, 
        creation: FileInfo.PlatformTimeSpec.PlatformFileTime? = nil
    ) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

        var times = (access, timespec())

        if let creation {
            times.1 = creation
            try execThrowingCFunction {
                withUnsafePointer(to: &times) { ptr in 
                    ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                        futimens(handle.unsafeRawHandle, reboundPtr)
                    }
                }
            }
        }

        times.1 = modification

        try execThrowingCFunction {
            withUnsafePointer(to: &times) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    futimens(handle.unsafeRawHandle, reboundPtr)
                }
            }
        }

        #else 

        var times = (access, modification)

        try execThrowingCFunction {
            withUnsafePointer(to: &times) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    futimens(handle.unsafeRawHandle, reboundPtr)
                }
            }
        }

        #endif 

    }


    func _writeFilePermission(forItemAt path: FilePath, permission: FilePermissions) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            lchmod(path.string, permission.rawValue)
        }

        #endif

    }


    func _writeFilePermission(for handle: borrowing UnsafeSystemHandle, permission: FilePermissions) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction {
            fchmod(handle.unsafeRawHandle, permission.rawValue)
        }

        #endif

    }


    #if canImport(WinSDK) || canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    func _writeFileFlags(forItemAt path: FilePath, flags: FileInfo.PlatformAttributes.RawValue) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        try execThrowingCFunction {
            lchflags(path.string, flags)
        }

        #endif

    }


    func _writeFileFlags(for handle: borrowing UnsafeSystemHandle, flags: FileInfo.PlatformAttributes.RawValue) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        try execThrowingCFunction {
            fchflags(handle.unsafeRawHandle, flags)
        }

        #endif

    }

    #else       // Linux, Android, WASI, where the flags provided by statx cannot be set directly

    func _writeFileFlags(forItemAt path: FilePath, inodeFlags: CInt) throws(SystemError) {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly(), noFollow: true))
        try _writeFileFlags(for: fd, inodeFlags: inodeFlags)
        try fd.close()
    }

    func _writeFileFlags(for handle: borrowing UnsafeSystemHandle, inodeFlags: CInt) throws(SystemError) {
        try execThrowingCFunction {
            ioctl(handle.unsafeRawHandle, _FS_IOC_SETFLAGS, inodeFlags)
        }
    }

    func _readFileInodeFlags(forItemAt path: FilePath) throws(SystemError) -> CInt {

        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: true))
        let flags = try _readFileInodeFlags(for: fd)

        try fd.close()

        return flags

    }

    func _readFileInodeFlags(for handle: borrowing UnsafeSystemHandle) throws(SystemError) -> CInt {

        var flags = 0 as CInt
        try execThrowingCFunction {
            ioctl(handle.unsafeRawHandle, _FS_IOC_GETFLAGS, &flags)
        }

        return flags

    }

    #endif 

}