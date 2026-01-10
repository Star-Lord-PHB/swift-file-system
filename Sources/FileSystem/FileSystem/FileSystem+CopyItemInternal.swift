import SystemPackage
import PlatformCLib
import CFileSystem



extension FileSystem {

    enum CopyOverwriteOption {
        case none 
        case skip
        case replace
    }


    fileprivate struct CachedCopySrcItemAttrs: ~Copyable {

        // this type is used instead of ``InternalFS.InternalFileTimes`` since we don't need ctime
        struct CachedFileTimes {
            let accessTime: CInterop.PlatformFileTime
            let modificationTime: CInterop.PlatformFileTime
            #if canImport(Darwin) || canImport(WinSDK) || os(FreeBSD) || os(OpenBSD)
            let creationTime: CInterop.PlatformFileTime
            #else
            let creationTime: CInterop.PlatformFileTime?
            #endif
        }

        let info: InternalFS.InternalRawFileInfo

        var type: FileType { info.type }

        var fileTimes: CachedFileTimes {
            .init(
                accessTime: info.accessTime, 
                modificationTime: info.modificationTime, 
                creationTime: creationTime
            )
        }

        var accessTime: CInterop.PlatformFileTime { info.accessTime }
        var modificationTime: CInterop.PlatformFileTime { info.modificationTime }
        var statusChangeTime: CInterop.PlatformFileTime { info.changeTime }
        #if canImport(Darwin) || canImport(WinSDK) || os(FreeBSD) || os(OpenBSD)
        var creationTime: CInterop.PlatformFileTime { info.creationTime }
        #else 
        var creationTime: CInterop.PlatformFileTime? { info.creationTime }
        #endif 

        #if canImport(Glibc) || canImport(Musl)
        // on Linux, inode flags are not available for symlinks
        let attributes: CInt?
        #else
        // on other platforms, file flags should always be available
        var attributes: CInterop.PlatformFileAttribute { info.attributes }
        #endif 

        #if canImport(WinSDK)
        let securityDescriptor: WindowsSelfRelativeSecurityDescriptor
        #else 
        var permission: FilePermissions { info.permissions }
        #endif

        // MARK: TODO: add platform specific extended attributes if necessary
    }


    fileprivate func _cacheItemAttrsForCopy(forHandle handle: borrowing UnsafeSystemHandle) throws(SystemError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        let info = try InternalFS.getRawFileInfo(from: handle)
        let sd = try InternalFS.getSecurityInfo(for: handle, members: .dacl)

        return .init(info: info, securityDescriptor: sd)

        #else 

        let info = try InternalFS.getRawFileInfo(from: handle)

        #if canImport(Glibc) || canImport(Musl)

        let flags = try InternalFS.readFileInodeFlags(for: handle)
        return .init(info: info, attributes: flags)

        #else

        return .init(info: info)

        #endif 

        #endif 

    }


    fileprivate func _cacheItemAttrsForCopy(forItemAt path: FilePath) throws(SystemError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        let info = try InternalFS.getRawFileInfo(forItemAt: path)
        let sd = try InternalFS.getSecurityInfo(forItemAt: path, members: .dacl)

        return .init(info: info, securityDescriptor: sd)

        #else 

        let info = try InternalFS.getRawFileInfo(forItemAt: path)

        #if canImport(Glibc) || canImport(Musl)

        let flags = if info.type != .symlink {
            try InternalFS.readFileInodeFlags(forItemAt: path)
        } else {
            nil as CInterop.PosixInodeFlags?
        }

        return .init(info: info, attributes: flags)

        #else

        return .init(info: info)

        #endif 

        #endif 

    }


    fileprivate func _writeCachedItemAttrsWithoutFileTime(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(SystemError) {

        #if canImport(WinSDK)

        try InternalFS.setFileAttributes(for: handle, attributes: cachedAttrs.attributes)

        let absoluteSd = try WindowsAbsoluteSecurityDescriptor(converting: cachedAttrs.securityDescriptor)

        try InternalFS.setFileSecurityInfo(
            for: handle, 
            setting: .dacl, 
            dacl: absoluteSd._dacl, 
            sacl: nil, 
            owner: nil, 
            group: nil
        )

        #else 

        try InternalFS.setFilePermissions(for: handle, permissions: cachedAttrs.permission)

        #if canImport(Glibc) || canImport(Musl)
        if let flags = cachedAttrs.attributes {
            try InternalFS.setFileInodeFlags(for: handle, flags: flags)
        }
        #else
        try InternalFS.setFileAttributes(for: handle, attributes: cachedAttrs.attributes)
        #endif

        #endif 

    }


    fileprivate func _writeCachedItemAttrsWithoutFileTime(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(SystemError) {
        
        #if canImport(WinSDK)

        try InternalFS.setFileAttributes(forItemAt: path, attributes: cachedAttrs.attributes)

        let absoluteSd = try WindowsAbsoluteSecurityDescriptor(converting: cachedAttrs.securityDescriptor)

        try InternalFS.setFileSecurityInfo(
            forItemAt: path, 
            setting: .dacl, 
            dacl: absoluteSd._dacl, 
            sacl: nil, 
            owner: nil, 
            group: nil
        )

        #else

        do {
            try InternalFS.setFilePermissions(forItemAt: path, permissions: cachedAttrs.permission)
        } catch let error where error.kind == .unsupported {
            // ignore unsupported error on setting permission
        }
        
        #if canImport(Glibc) || canImport(Musl)
        if let flags = cachedAttrs.attributes {
            do {
                try InternalFS.setFileInodeFlags(forItemAt: path, flags: flags)
            } catch let error where error.kind == .unsupported || error.kind == .isADirectory {
                // ignore unsupported error and is a dir error on setting inode flags
            }
        }
        #else
        try InternalFS.setFileAttributes(forItemAt: path, attributes: cachedAttrs.attributes)
        #endif

        #endif 

    }

}



extension FileSystem {

    func _copyItemNoFollow(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption) throws(SystemError) {
        
        let srcAttrs = try _cacheItemAttrsForCopy(forItemAt: srcPath)
        let type = srcAttrs.type

        switch type {
            case .regular:
                try _copyFile(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)
            case .symlink:
                try _copySymlink(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)
            case .directory:
                try _copyDirectoryRecursive(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)
            default:
                throw .init(code: .notSupported)!
        }

    }


    // assume that the srcPath directly points to a regular file (not a directory or symlink)
    fileprivate func _copyFile(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption, srcAttrs: consuming CachedCopySrcItemAttrs? = nil) throws(SystemError) {

        #if canImport(WinSDK)

        let srcCachedAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forItemAt: srcPath) }

        assert(srcCachedAttrs.type == .regular, "srcCachedAttrs must represent a regular file")

        try _copyFileOrSymlink(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcCachedAttrs)
        
        #else

        let srcHandle = try UnsafeSystemHandle.open(at: srcPath, openOptions: .init(access: .readOnly(), noFollow: true))
        let srcCachedAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forHandle: srcHandle) }
        try _copyFile(from: srcHandle, to: dstPath, overwrite: overwrite, srcPath: srcPath, srcFileAttrs: srcCachedAttrs)
        try srcHandle.close()

        #endif  // canImport(WinSDK)

    }


    #if canImport(WinSDK)
    @available(*, unavailable, message: "Not meaningful on Windows")
    #endif 
    fileprivate func _copyFile(
        from srcHandle: borrowing UnsafeSystemHandle, 
        to dstPath: FilePath, 
        overwrite: CopyOverwriteOption, 
        srcPath: FilePath, 
        srcFileAttrs: consuming CachedCopySrcItemAttrs,
    ) throws(SystemError) {

        assert(srcFileAttrs.type == .regular, "srcFileAttrs must represent a regular file")

        #if canImport(WinSDK)

        throw SystemError(code: .extended(.notImplemented))!
        
        #else

        let dstHandle: UnsafeSystemHandle
        let tmpDstPath: FilePath
        let shouldRename: Bool

        let dstFileType = try? FileType(mode: InternalFS.ulstat(dstPath).st_mode)

        switch (dstFileType, overwrite) {
            case (.some(_), .none): 
                throw SystemError(code: .fileExists)!
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
                } catch let error where error.kind == .alreadyExists && overwrite == .skip {
                    return
                } catch let error where error.kind == .alreadyExists && overwrite == .replace {
                    fallthrough     // if fail, fallthrough to copy to temp file 
                }
                tmpDstPath = dstPath
                shouldRename = false
                dstHandle = handle
            case (.some(.symlink), .replace), (.some(.regular), .replace):
                let tmpFileResult = try InternalFS.makeTmpFile(baseOn: dstPath)
                tmpDstPath = tmpFileResult.path
                dstHandle = tmpFileResult.takeHandle()
                shouldRename = true
            case (.some(.directory), .replace): 
                throw SystemError(code: .isADirectory)!
            case (.some(_), .replace): 
                throw SystemError(code: .notSupported)!
        }

        do {
            try InternalFS.copyRegularFile(from: srcHandle, to: dstHandle)
            try? InternalFS.setFileTimes(for: srcHandle, access: srcFileAttrs.accessTime, modification: nil)
            try _writeCachedItemAttrsWithoutFileTime(forHandle: dstHandle, cachedAttrs: srcFileAttrs)
            try InternalFS.setFileTimes(for: dstHandle, access: srcFileAttrs.accessTime, modification: srcFileAttrs.modificationTime, creation: srcFileAttrs.creationTime)
            if shouldRename {
                try InternalFS.rename(itemAt: tmpDstPath, to: dstPath)
            }
        } catch {
            try? InternalFS.unlink(fileAt: tmpDstPath)  // error of this operation is ignored
            error.code.rawValue.map { errno = $0 }      // restore errno
            throw error
        }

        #endif  // canImport(WinSDK)

    }


    // assume that the srcPath directly points to a symlink (not a regular file or directory)
    fileprivate func _copySymlink(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption, srcAttrs: consuming CachedCopySrcItemAttrs? = nil) throws(SystemError) {

        let srcAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forItemAt: srcPath) }

        assert(srcAttrs.type == .symlink, "srcAttrs must represent a symlink")

        #if canImport(WinSDK)

        try _copyFileOrSymlink(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)

        #else 

        let dstFileType = try? FileType(mode: InternalFS.ulstat(dstPath).st_mode)

        switch (dstFileType, overwrite) {
            case (.some(_), .none): 
                throw SystemError(code: .fileExists)!
            case (.none, .none):
                // TODO: remove the copied symlink if fail to write the cached attributes
                let targetPath = try InternalFS.readlink(fromSymlinkAt: srcPath)
                try InternalFS.symlink(dstPath: targetPath, linkPath: dstPath)
                do {
                    try _writeCachedItemAttrsWithoutFileTime(forItemAt: dstPath, cachedAttrs: srcAttrs)
                    try InternalFS.setFileTimes(forItemAt: dstPath, access: srcAttrs.accessTime, modification: srcAttrs.modificationTime, creation: srcAttrs.creationTime)
                    try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil)
                } catch {
                    try? InternalFS.unlink(fileAt: dstPath)
                    error.code.rawValue.map { errno = $0 }
                    throw error
                }
            case (.some(_), .skip):
                return
            case (.some(.symlink), .replace), (.some(.regular), .replace), (.none, .replace), (.none, .skip):
                let targetPath = try InternalFS.readlink(fromSymlinkAt: srcPath)
                var dstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                var created = false
                for _ in 0 ..< 24 {
                    do {
                        try InternalFS.symlink(dstPath: targetPath, linkPath: dstTmpPath)
                        created = true
                        break
                    } catch let error where error.kind == .alreadyExists {
                        dstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                    }
                }
                guard created else {
                    errno = FsErrorCode.PlatformErrorCode.fileExists.rawValue
                    throw SystemError(code: .fileExists)!
                }
                do {
                    try _writeCachedItemAttrsWithoutFileTime(forItemAt: dstTmpPath, cachedAttrs: srcAttrs)
                    try InternalFS.setFileTimes(forItemAt: dstTmpPath, access: srcAttrs.accessTime, modification: srcAttrs.modificationTime, creation: srcAttrs.creationTime)
                    try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil)
                    try InternalFS.rename(itemAt: dstTmpPath, to: dstPath)
                } catch {
                    try? InternalFS.unlink(fileAt: dstTmpPath)
                    error.code.rawValue.map { errno = $0 }
                    throw error
                }
            case (.some(.directory), .replace):
                throw SystemError(code: .isADirectory)!
            case (.some(_), .replace):
                throw SystemError(code: .notSupported)!
        }

        #endif 

    }


    #if canImport(WinSDK)
    fileprivate func _copyFileOrSymlink(
        from srcPath: FilePath,
        to dstPath: FilePath,
        overwrite: CopyOverwriteOption,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(SystemError) {

        assert(
            srcAttrs.type == .regular || srcAttrs.type == .symlink, 
            "srcAttrs must represent a regular file or a symlink"
        )

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let tmpDstPath: FilePath
        let shouldRename: Bool

        switch (overwrite, dstFileType) {
            case (.none, .some(_)): throw SystemError(code: .fileExists)!
            case (.skip, .some(_)): return
            case (.none, .none), (.skip, .none): 
                tmpDstPath = dstPath
                shouldRename = false
                do {
                    try InternalFS.copyRegularFileOrSymlink(from: srcPath, to: tmpDstPath, overwrite: false)
                } catch let error where error.kind == .alreadyExists && overwrite == .skip {
                    return
                }
            case (.replace, .directory) : throw SystemError(code: .isADirectory)!
            case (.replace, _):
                var tmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                shouldRename = true
                var copied = false
                for _ in 0 ..< 24 {
                    do {
                        try InternalFS.copyRegularFileOrSymlink(from: srcPath, to: tmpPath, overwrite: false)
                        copied = true
                        break
                    } catch let error where error.kind == .alreadyExists { /* ignore */ }
                    tmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                }
                guard copied else {
                    SetLastError(FsErrorCode.PlatformErrorCode.fileExists.rawValue)
                    throw SystemError(code: .fileExists)! 
                }
                tmpDstPath = tmpPath
        }

        do {
            try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil)
            try _writeCachedItemAttrsWithoutFileTime(forItemAt: tmpDstPath, cachedAttrs: srcAttrs)
            try InternalFS.setFileTimes(forItemAt: tmpDstPath, access: srcAttrs.accessTime, modification: srcAttrs.modificationTime, creation: srcAttrs.creationTime)
            if shouldRename {
                try InternalFS.rename(itemAt: tmpDstPath, to: dstPath)
            }
        } catch {
            try? InternalFS.unlink(fileAt: tmpDstPath)      // error of this operation is ignored
            error.code.rawValue.map { SetLastError($0) }    // restore errno
            throw error
        }

    }
    #endif 


    // return whether a new directory is actually created
    fileprivate func _makeEmptyDirectoryForCopy(at dstPath: FilePath, overwrite: CopyOverwriteOption) throws(SystemError) -> Bool {
        do {
            try InternalFS.mkdir(at: dstPath, permissions: nil)
            return true
        } catch let error where error.kind == .alreadyExists {
            switch overwrite{
                case .none:     throw error
                case .skip:     return false
                case .replace:  return true
            }
        }
    }


    fileprivate func _copyDirectoryRecursive(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption, srcAttrs: consuming CachedCopySrcItemAttrs? = nil) throws(SystemError) {

        let srcAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forItemAt: srcPath) }

        assert(srcAttrs.type == .directory, "srcAttrs must represent a directory")

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        switch (dstFileType, overwrite) {
            case (.some(_), .none):                                 throw SystemError(code: .fileExists)!
            case (.some(let type), .skip) where type != .directory: return
            case (.some(let type), _) where type != .directory:     throw SystemError(code: .notADirectory)!
            case (_, _):                                            break
        }

        /// Store the file times to be copied to the destination dir and the original access time of the source dir to be restored later
        struct DirFileTimesItem {
            let fileTimesToCopy: CachedCopySrcItemAttrs.CachedFileTimes?
            let cachedSrcAccessTime: CInterop.PlatformFileTime
            init(fileTimesToCopy: CachedCopySrcItemAttrs.CachedFileTimes? = nil, cachedSrcAccessTime: CInterop.PlatformFileTime) {
                self.fileTimesToCopy = fileTimesToCopy
                self.cachedSrcAccessTime = cachedSrcAccessTime
            }
            init(fileTimesToCopy: CachedCopySrcItemAttrs.CachedFileTimes) {
                self.init(fileTimesToCopy: fileTimesToCopy, cachedSrcAccessTime: fileTimesToCopy.accessTime)
            }
        }

        var dirFileTimesStack = [DirFileTimesItem]()

        if try _makeEmptyDirectoryForCopy(at: dstPath, overwrite: overwrite) {
            try _writeCachedItemAttrsWithoutFileTime(forItemAt: dstPath, cachedAttrs: srcAttrs)
            dirFileTimesStack.append(.init(fileTimesToCopy: srcAttrs.fileTimes))
        } else {
            let srcAccessTime = try InternalFS.getFileTimes(fromItemAt: srcPath).accessTime
            dirFileTimesStack.append(.init(cachedSrcAccessTime: srcAccessTime))
        }

        var enumerator = try DirectoryEntryRecursiveEnumerator(path: srcPath, doStat: true)

        while let enumerationElement = try enumerator.next() {

            if case .leavingDir(let path) = enumerationElement {
                guard let item = dirFileTimesStack.popLast() else { continue }
                if let times = item.fileTimesToCopy {
                    try InternalFS.setFileTimes(forItemAt: dstPath.appending(path.components), access: times.accessTime, modification: times.modificationTime, creation: times.creationTime)
                }
                try? InternalFS.setFileTimes(forItemAt: srcPath.appending(path.components), access: item.cachedSrcAccessTime, modification: nil)
                continue
            }

            guard case .entry(let entry) = enumerationElement else { continue }
            guard entry.path.lastComponent?.kind == .regular else { continue }

            switch entry.type {
                case .regular: 
                    try _copyFile(
                        from: srcPath.appending(entry.path.components), 
                        to: dstPath.appending(entry.path.components), 
                        overwrite: overwrite
                    )
                case .symlink: 
                    try _copySymlink(
                        from: srcPath.appending(entry.path.components), 
                        to: dstPath.appending(entry.path.components), 
                        overwrite: overwrite
                    )
                case .directory: 
                    if try _makeEmptyDirectoryForCopy(at: dstPath.appending(entry.path.components), overwrite: overwrite) {
                        let cachedAttr = try _cacheItemAttrsForCopy(forItemAt: srcPath.appending(entry.path.components))
                        try _writeCachedItemAttrsWithoutFileTime(forItemAt: dstPath.appending(entry.path.components), cachedAttrs: cachedAttr)
                        dirFileTimesStack.append(.init(fileTimesToCopy: cachedAttr.fileTimes))
                    } else {
                        let srcAccessTime = try InternalFS.getFileTimes(fromItemAt: srcPath.appending(entry.path.components)).accessTime
                        dirFileTimesStack.append(.init(cachedSrcAccessTime: srcAccessTime))
                    }
                default: break
            }

        }

        if let item = dirFileTimesStack.popLast() {
            if let times = item.fileTimesToCopy {
                try InternalFS.setFileTimes(forItemAt: dstPath, access: times.accessTime, modification: times.modificationTime, creation: times.creationTime)
            }
            try? InternalFS.setFileTimes(forItemAt: srcPath, access: item.cachedSrcAccessTime, modification: nil)
        }

    }

}