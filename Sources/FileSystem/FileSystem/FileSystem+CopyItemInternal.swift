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

        let info: InternalFS.InternalRawFileInfo

        var type: FileInfo.FileType { info.type }

        var accessTime: CInterop.PlatformFileTime { info.accessTime }
        var modificationTime: CInterop.PlatformFileTime { info.modificationTime }
        var statusChangeTime: CInterop.PlatformFileTime { info.changeTime }
        var creationTime: CInterop.PlatformFileTime? { info.creationTime }

        #if canImport(Glibc) || canImport(Musl)
        // on Linux, inode flags are not available for symlinks
        let attributes: CInt?
        #else
        // on other platforms, file flags should always be available
        var attributes: CInterop.PlatformFileAttribute { info.attributes }
        #endif 

        #if canImport(Windows)
        #warning("Windows permission not implemented")
        #else 
        var permission: FilePermissions { info.permissions }
        #endif

        // MARK: TODO: add platform specific extended attributes if necessary
    }


    fileprivate func _cacheItemAttrsForCopy(forHandle handle: borrowing UnsafeSystemHandle) throws(SystemError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

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

        #warning("Not implemented")
        fatalError("Not implemented")

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


    fileprivate func _writeCachedItemAttrs(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: CachedCopySrcItemAttrs
    ) throws(SystemError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try InternalFS.setFileTimes(
            for: handle, 
            access: cachedAttrs.accessTime, 
            modification: cachedAttrs.modificationTime,
            creation: cachedAttrs.creationTime
        )

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


    fileprivate func _writeCachedItemAttrs(forItemAt path: FilePath, cachedAttrs: CachedCopySrcItemAttrs) throws(SystemError) {
        
        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        try InternalFS.setFileTimes(
            forItemAt: path,
            access: cachedAttrs.accessTime, 
            modification: cachedAttrs.modificationTime, 
            creation: cachedAttrs.creationTime
        )

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

        switch srcAttrs.type {
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

        let dstFileType = try? FileInfo.FileType(mode: InternalFS.ulstat(dstPath).st_mode)

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
            try _writeCachedItemAttrs(forHandle: dstHandle, cachedAttrs: srcFileAttrs)
            try? InternalFS.setFileTimes(for: srcHandle, access: srcFileAttrs.accessTime, modification: nil)
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
    fileprivate func _copySymlink(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption, srcAttrs: CachedCopySrcItemAttrs? = nil) throws(SystemError) {

        let srcAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forItemAt: srcPath) }

        assert(srcAttrs.type == .symlink, "srcAttrs must represent a symlink")

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        // TODO: copy symlink attributes if necessary

        let dstFileType = try? FileInfo.FileType(mode: InternalFS.ulstat(dstPath).st_mode)

        switch (dstFileType, overwrite) {
            case (.some(_), .none): 
                throw SystemError(code: .fileExists)!
            case (.none, .none):
                let targetPath = try InternalFS.readlink(fromSymlinkAt: srcPath)
                try InternalFS.symlink(dstPath: targetPath, linkPath: dstPath)
                try _writeCachedItemAttrs(forItemAt: dstPath, cachedAttrs: srcAttrs)
                try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil)
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
                    errno = PlatformErrorCode.fileExists.rawValue
                    throw SystemError(code: .fileExists)!
                }
                do {
                    try _writeCachedItemAttrs(forItemAt: dstTmpPath, cachedAttrs: srcAttrs)
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


    // return whether a new directory is actually created
    func _makeEmptyDirectoryForCopy(at dstPath: FilePath, overwrite: CopyOverwriteOption) throws(SystemError) -> Bool {
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


    fileprivate func _copyDirectoryRecursive(from srcPath: FilePath, to dstPath: FilePath, overwrite: CopyOverwriteOption, srcAttrs: CachedCopySrcItemAttrs? = nil) throws(SystemError) {

        let srcAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forItemAt: srcPath) }

        assert(srcAttrs.type == .directory, "srcAttrs must represent a directory")

        let dstFileType = try? FileInfo.FileType(mode: InternalFS.ulstat(dstPath).st_mode)

        switch (dstFileType, overwrite) {
            case (.some(_), .none): 
                throw SystemError(code: .fileExists)!
            case (.some(let type), .skip) where type != .directory:
                return
            case (.some(let type), _) where type != .directory:
                throw SystemError(code: .notADirectory)!
            case (_, _): 
                break
        }

        var dirCachedAttrStack = [(cachedAttr: CachedCopySrcItemAttrs, created: Bool)]()

        dirCachedAttrStack.append(
            (srcAttrs, try _makeEmptyDirectoryForCopy(at: dstPath, overwrite: overwrite))
        )

        var enumerator = try DirectoryEntryRecursiveEnumerator(path: srcPath, doStat: true)

        while let enumerationElement = try enumerator.next() {

            print(enumerationElement)

            if case .leavingDir(let path) = enumerationElement {
                guard let (cachedAttr, dirCreated) = dirCachedAttrStack.popLast() else { continue }
                if dirCreated {
                    try _writeCachedItemAttrs(forItemAt: dstPath.appending(path.components), cachedAttrs: cachedAttr)
                }
                try? InternalFS.setFileTimes(forItemAt: srcPath.appending(path.components), access: cachedAttr.accessTime, modification: nil)
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
            try? InternalFS.setFileTimes(forItemAt: srcPath, access: cachedAttr.accessTime, modification: nil)
        }

    }

}