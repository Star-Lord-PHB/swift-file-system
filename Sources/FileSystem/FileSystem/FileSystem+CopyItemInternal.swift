import SystemPackage
import PlatformCLib
import CFileSystem



extension FileSystem {

    enum CopyOverwriteOption {
        case none 
        case skip
        case replace
    }


    fileprivate struct CachedCopySrcItemAttrs {

        let type: FileInfo.FileType

        #if canImport(WinSDK)
        typealias PlatformTimeType = FILETIME
        #else
        typealias PlatformTimeType = timespec
        #endif

        let accessTime: PlatformTimeType
        let modificationTime: PlatformTimeType
        let statusChangeTime: PlatformTimeType
        let creationTime: PlatformTimeType?

        #if canImport(Glibc) || canImport(Musl)
        let attributes: CInt?       // on Linux, inode flags are not available for symlinks
        #else
        let attributes: FileInfo.PlatformAttributes.RawValue        // on other platforms, file flags should always be available
        #endif 

        #if canImport(Windows)
        #warning("Windows permission not implemented")
        #else 
        let permission: FilePermissions
        #endif

        // MARK: TODO: add platform specific extended attributes if necessary
    }


    fileprivate func _cacheItemAttrsForCopy(forHandle handle: borrowing UnsafeSystemHandle) throws(SystemError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        var st = stat()
        try execThrowingCFunction {
            fstat(handle.unsafeRawHandle, &st)
        }

        #if canImport(Glibc) || canImport(Musl)

        let flags = try _readFileInodeFlags(for: handle.unsafeRawHandle)

        return .init(
            type: .init(mode: st.st_mode),
            accessTime: st.st_atim, 
            modificationTime: st.st_mtim, 
            statusChangeTime: st.st_ctim, 
            creationTime: nil, 
            attributes: flags,
            permission: .init(rawValue: st.st_mode & 0o7777)
        )

        #else

        return .init(
            type: .init(mode: st.st_mode),
            accessTime: st.st_atimespec, 
            modificationTime: st.st_mtimespec, 
            statusChangeTime: st.st_ctimespec, 
            creationTime: st.st_birthtimespec, 
            attributes: st.st_flags, 
            permission: .init(rawValue: st.st_mode & 0o7777)
        )

        #endif 

        #endif 

    }


    fileprivate func _cacheItemAttrsForCopy(forItemAt path: FilePath) throws(SystemError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        var st = stat()
        try execThrowingCFunction {
            lstat(path.string, &st)
        }

        #if canImport(Glibc) || canImport(Musl)

        let flags = if FileInfo.FileType(mode: st.st_mode) != .symlink {
            try _readFileInodeFlags(forItemAt: path)
        } else {
            nil as PlatformFlagType?
        }

        return .init(
            type: .init(mode: st.st_mode),
            accessTime: st.st_atim, 
            modificationTime: st.st_mtim, 
            statusChangeTime: st.st_ctim, 
            creationTime: nil, 
            attributes: flags,
            permission: .init(rawValue: st.st_mode & 0o7777)
        )

        #else

        return .init(
            type: .init(mode: st.st_mode),
            accessTime: st.st_atimespec, 
            modificationTime: st.st_mtimespec, 
            statusChangeTime: st.st_ctimespec, 
            creationTime: st.st_birthtimespec, 
            attributes: st.st_flags, 
            permission: .init(rawValue: st.st_mode & 0o7777)
        )

        #endif 

        #endif 

    }


    fileprivate func _writeCachedItemAttrs(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: CachedCopySrcItemAttrs
    ) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try _writeFileTime(
            for: handle, 
            access: cachedAttrs.accessTime, 
            modification: cachedAttrs.modificationTime, 
            statusChange: cachedAttrs.statusChangeTime, 
            creation: cachedAttrs.creationTime
        )

        try _writeFilePermission(for: handle, permission: cachedAttrs.permission)

        #if canImport(Glibc) || canImport(Musl)
        if let flags = cachedAttrs.attributes {
            try _writeFileFlags(for: handle, flags: flags)
        }
        #else
        try _writeFileFlags(for: handle, flags: cachedAttrs.attributes)
        #endif

        #endif 

    }


    fileprivate func _writeCachedItemAttrs(forItemAt path: FilePath, cachedAttrs: CachedCopySrcItemAttrs) throws(SystemError) {
        
        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        try _writeFileTime(
            forItemAt: path,
            access: cachedAttrs.accessTime, 
            modification: cachedAttrs.modificationTime, 
            statusChange: cachedAttrs.statusChangeTime, 
            creation: cachedAttrs.creationTime
        )

        try _writeFilePermission(forItemAt: path, permission: cachedAttrs.permission)
        #if canImport(Glibc) || canImport(Musl)
        if let flags = cachedAttrs.attributes {
            try _writeFileFlags(forItemAt: path, flags: flags)
        }
        #else
        try _writeFileFlags(forItemAt: path, flags: cachedAttrs.attributes)
        #endif

        #endif 

    }


    fileprivate func _writeAccessTime(for handle: borrowing UnsafeSystemHandle, cachedAttrs: CachedCopySrcItemAttrs) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        var currentTimes = (cachedAttrs.accessTime, cachedAttrs.modificationTime)

        try execThrowingCFunction {
            withUnsafePointer(to: &currentTimes) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    futimens(handle.unsafeRawHandle, reboundPtr)
                }
            }
        }

        #endif

    }


    fileprivate func _writeAccessTime(forItemAt path: FilePath, cachedAttrs: CachedCopySrcItemAttrs) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        var currentTimes = (cachedAttrs.accessTime, cachedAttrs.modificationTime)

        try execThrowingCFunction {
            withUnsafePointer(to: &currentTimes) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    utimensat(AT_FDCWD, path.string, reboundPtr, AT_SYMLINK_NOFOLLOW)
                }
            }
        }

        #endif

    }


}



extension FileSystem {

    func _copyItemNoFollow(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption) throws(SystemError) {
        
        let srcAttrs = try _cacheItemAttrsForCopy(forItemAt: srcPath)

        switch srcAttrs.type {
            case .regular:
                try _copyFile(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)
            case .symlink:
                try _copySymlink(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)
            case .directory:
                try _copyDirectoryRecursive(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)
            default:
                throw .init(code: EOPNOTSUPP)
        }

    }


    // assume that the srcPath directly points to a regular file (not a directory or symlink)
    fileprivate func _copyFile(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption, srcAttrs: CachedCopySrcItemAttrs? = nil) throws(SystemError) {

        #if canImport(WinSDK)
  
        #warning("Not implemented")
        fatalError("Not implemented")
        
        #else

        let srcHandle = try UnsafeSystemHandle.open(at: srcPath, openOptions: .init(access: .readOnly(), noFollow: true))
        let srcCachedAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forHandle: srcHandle) }
        try _copyFile(from: srcHandle, to: dstPath, overwrite: overwrite, srcPath: srcPath, srcFileAttrs: srcCachedAttrs)
        try srcHandle.close()

        #endif  // canImport(WinSDK)

    }


    fileprivate func _copyFile(
        from srcHandle: borrowing UnsafeSystemHandle, 
        to dstPath: FilePath, 
        overwrite: CopyOverwriteOption, 
        srcPath: FilePath, 
        srcFileAttrs: CachedCopySrcItemAttrs,
    ) throws(SystemError) {

        assert(srcFileAttrs.type == .regular, "srcFileAttrs must represent a regular file")

        #if canImport(WinSDK)
  
        #warning("Not implemented")
        fatalError("Not implemented")
        
        #else

        let dstHandle: UnsafeSystemHandle
        let tmpDstPath: FilePath
        let shouldRename: Bool

        var dstStat = stat()
        let dstFileType = if lstat(dstPath.string, &dstStat) == 0 {
            FileInfo.FileType(mode: dstStat.st_mode)
        } else {
            nil as FileInfo.FileType?
        }

        switch (dstFileType, overwrite) {
            case (.some(_), .none): 
                throw SystemError(code: EEXIST)
            case (.none, .none): 
                tmpDstPath = dstPath
                shouldRename = false
                dstHandle = try UnsafeSystemHandle.open(
                    at: dstPath,
                    openOptions: .init(access: .writeOnly(), creation: .assertMissing, noFollow: true)
                )
            case (.some(_), .skip): 
                return
            case (.none, .replace), (.none, .skip): 
                let handle: UnsafeSystemHandle
                do {
                    // try to create directly
                    handle = try UnsafeSystemHandle.open(
                        at: dstPath,
                        openOptions: .init(access: .writeOnly(), creation: .assertMissing, noFollow: true)
                    )
                } catch let error where error.code == EEXIST && overwrite == .skip {
                    return
                } catch let error where error.code == EEXIST && overwrite == .replace {
                    fallthrough
                }
                tmpDstPath = dstPath
                shouldRename = false
                dstHandle = handle
            case (.some(.symlink), .replace), (.some(.regular), .replace):
                var tmpPathBuffer = (dstPath.string + ".tmp.XXXXXX").utf8CString
                let fd = tmpPathBuffer.withUnsafeMutableBufferPointer { ptr in
                    mkstemp(ptr.baseAddress!)
                }
                guard fd >= 0 else {
                    try SystemError.assertError()
                }
                tmpDstPath = tmpPathBuffer.withUnsafeBufferPointer { .init(platformString: $0.baseAddress!) }
                shouldRename = true
                dstHandle = .init(owningRawHandle: fd)
            case (.some(.directory), .replace): 
                throw SystemError(code: EISDIR)
            case (.some(_), .replace): 
                throw SystemError(code: EOPNOTSUPP)
        }

        #if canImport(Darwin)

        // on Darwin, attributes of file will be copied by fcopyfile, no need to do it manually

        do {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_ALL))
            try _writeCachedItemAttrs(forHandle: dstHandle, cachedAttrs: srcFileAttrs)
            try? _writeAccessTime(for: srcHandle, cachedAttrs: srcFileAttrs)
            if shouldRename {
                try execThrowingCFunction {
                    rename(tmpDstPath.string, dstPath.string)
                }
            }
        } catch {
            unlink(tmpDstPath.string)
            errno = error.code
            throw error
        }

        try dstHandle.close()

        #else

        // some weird compiler bug here, need to move the dstHandle to a new local constant
        let dstHandleMoved = consume dstHandle

        do {

            var srcOffset: off_t = 0
            var dstOffset: off_t = 0
            var fallbackToManualCopy = false

            while true {
                // faster path using copy_file_range if available

                let byteCopied = copy_file_range(srcHandle.unsafeRawHandle, &srcOffset, dstHandleMoved.unsafeRawHandle, &dstOffset, Int(srcFileSize ?? 0x7ffff000), 0)
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
                        _ = try dstHandleMoved.write(contentsOf: ptr)
                    }

                    if bytesRead < buffer.count { break }

                }

            }

            try _writeCachedItemAttrs(forHandle: dstHandleMoved, cachedAttrs: srcFileAttrs)
            try? _writeAccessTime(for: srcHandle, cachedAttrs: srcFileAttrs)

            if shouldRename {
                try execThrowingCFunction {
                    rename(tmpDstPath.string, dstPath.string)
                }
            }

        } catch {
            unlink(tmpDstPath.string)
            errno = error.code
            throw error
        }

        try dstHandleMoved.close()

        #endif  // canImport(Darwin)

        #endif  // canImport(WinSDK)

    }


    // assume that the srcPath directly points to a symlink (not a regular file or directory)
    fileprivate func _copySymlink(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption, srcAttrs: CachedCopySrcItemAttrs? = nil) throws(SystemError) {

        let srcAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forItemAt: srcPath) }

        assert(srcAttrs.type == .symlink, "srcAttrs must represent a symlink")

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        // TODO: copy symlink attributes if necessary

        var dstStat = stat()
        let dstFileType = if lstat(dstPath.string, &dstStat) == 0 {
            FileInfo.FileType(mode: dstStat.st_mode)
        } else {
            nil as FileInfo.FileType?
        }

        switch (dstFileType, overwrite) {
            case (.some(_), .none): 
                throw SystemError(code: EEXIST)
            case (.none, .none):
                let targetPath = try _symlinkDirectDestination(of: srcPath)
                try execThrowingCFunction {
                    symlink(targetPath.string, dstPath.string)
                }
                try _writeCachedItemAttrs(forItemAt: dstPath, cachedAttrs: srcAttrs)
                try? _writeAccessTime(forItemAt: srcPath, cachedAttrs: srcAttrs)
            case (.some(_), .skip):
                return
            case (.some(.symlink), .replace), (.some(.regular), .replace), (.none, .replace), (.none, .skip):
                let targetPath = try _symlinkDirectDestination(of: srcPath)
                var dstTmpPath: FilePath = _tmpFileName(basedOn: dstPath)
                var created = false
                for _ in 0 ..< 24 {
                    if symlink(targetPath.string, dstTmpPath.string) == 0 { 
                        created = true
                        break 
                    }
                    if errno != EEXIST {
                        try SystemError.assertError()
                    }
                    dstTmpPath = _tmpFileName(basedOn: dstPath)
                }
                guard created else {
                    errno = EAGAIN
                    throw SystemError(code: EAGAIN)
                }
                try _writeCachedItemAttrs(forItemAt: dstTmpPath, cachedAttrs: srcAttrs)
                try? _writeAccessTime(forItemAt: srcPath, cachedAttrs: srcAttrs)
                if rename(dstTmpPath.string, dstPath.string) != 0 {
                    let errorCode = errno
                    unlink(dstTmpPath.string)
                    errno = errorCode
                    throw SystemError(code: errorCode)
                }
            case (.some(.directory), .replace):
                throw SystemError(code: EISDIR)
            case (.some(_), .replace):
                throw SystemError(code: EOPNOTSUPP)
        }

        #endif 

    }


    // return whether a new directory is actually created
    func _makeEmptyDirectoryForCopy(at dstPath: FilePath, overwrite: CopyOverwriteOption) throws(SystemError) -> Bool {
        do {
            try _createDirectoryNoIntermediate(at: dstPath)
            return true
        } catch let error where error.code == platformItemAlreadyExistsErrorCode.rawValue {
            switch overwrite{
                case .none:     throw error
                case .skip:     return false
                case .replace:  return true
            }
        }
    }


    fileprivate func _copyDirectoryRecursive(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption, srcAttrs: CachedCopySrcItemAttrs? = nil) throws(SystemError) {

        let srcAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forItemAt: srcPath) }

        assert(srcAttrs.type == .directory, "srcAttrs must represent a directory")

        var dstStat = stat()
        let dstFileType = if lstat(dstPath.string, &dstStat) == 0 {
            FileInfo.FileType(mode: dstStat.st_mode)
        } else {
            nil as FileInfo.FileType?
        }

        switch (dstFileType, overwrite) {
            case (.some(_), .none): 
                throw SystemError(code: EEXIST)
            case (.some(let type), .skip) where type != .directory:
                return
            case (.some(let type), _) where type != .directory:
                throw SystemError(code: ENOTDIR)
            case (_, _): 
                break
        }

        var dirCachedAttrStack = [(cachedAttr: CachedCopySrcItemAttrs, created: Bool)]()

        dirCachedAttrStack.append(
            (srcAttrs, try _makeEmptyDirectoryForCopy(at: dstPath, overwrite: overwrite))
        )

        var enumerator = try DirectoryEntryRecursiveEnumerator(path: srcPath, doStat: true)

        while let enumerationElement = try enumerator.next() {

            if case .leavingDir(let path) = enumerationElement {
                guard let (cachedAttr, dirCreated) = dirCachedAttrStack.popLast() else { continue }
                if dirCreated {
                    try _writeCachedItemAttrs(forItemAt: dstPath.appending(path.components), cachedAttrs: cachedAttr)
                }
                try _writeAccessTime(forItemAt: srcPath.appending(path.components), cachedAttrs: cachedAttr)
                continue
            }

            guard case .entry(let entry) = enumerationElement else { continue }
            guard entry.path.lastComponent?.kind == .regular else { continue }

            switch entry.type {
                case .regular: try _copyFile(
                    from: srcPath.appending(entry.path.components), 
                    to: dstPath.appending(entry.path.components), 
                    overwrite: overwrite
                )
                case .symlink: try _copySymlink(
                    from: srcPath.appending(entry.path.components), 
                    to: dstPath.appending(entry.path.components), 
                    overwrite: overwrite
                )
                case .directory: dirCachedAttrStack.append(
                    (
                        try _cacheItemAttrsForCopy(forItemAt: srcPath.appending(entry.path.components)), 
                        try _makeEmptyDirectoryForCopy(at: dstPath.appending(entry.path.components), overwrite: overwrite)
                    )
                )
                default: break
            }

        }

        if let (cachedAttr, dirCreated) = dirCachedAttrStack.popLast() {
            if dirCreated {
                try _writeCachedItemAttrs(forItemAt: dstPath, cachedAttrs: cachedAttr)
            }
            try _writeAccessTime(forItemAt: srcPath, cachedAttrs: cachedAttr)
        }

    }


    func _tmpFileName(basedOn path: FilePath) -> FilePath {
        #if canImport(WinSDK)
        let pid = GetCurrentProcessId()
        #else 
        let pid = getpid()
        #endif
        assert(path.lastComponent != nil, "base path for temp file name must not be empty")
        let lastComponent = FilePath.Component("\(path.lastComponent!).tmp-\(pid)-\(String(UInt64.random(in: 0 ... .max), radix: 16))")!
        return path.removingLastComponent().appending(lastComponent)
    }

}