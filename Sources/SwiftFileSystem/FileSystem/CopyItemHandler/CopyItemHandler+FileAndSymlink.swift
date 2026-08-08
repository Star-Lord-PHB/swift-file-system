import FileSystemCore
import struct SystemPackage.FilePath



extension CopyItemHandler {

    // assume that the item at `itemRelativePath` directly points to a regular file (not a directory or symlink)
    mutating func copyFile(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) throws(LowLevelError) {

        #if canImport(WinSDK)

        let srcCachedAttrs = if let srcAttrs {
            srcAttrs
        } else {
            try cacheItemAttrsForCopy(forItemAt: srcAbsolutePath(of: itemRelativePath))
        }
        assert(srcCachedAttrs.type == .regular, "srcCachedAttrs must represent a regular file")

        try copyWindowFileOrSymlink(itemRelativePath: itemRelativePath, srcAttrs: srcCachedAttrs)

        #else

        let srcHandle = try UnsafeSystemHandle.open(
            at: srcAbsolutePath(of: itemRelativePath),
            openOptions: .init(access: .readOnly(), noFollow: true)
        )
        let srcCachedAttrs = if let srcAttrs { srcAttrs } else { try cacheItemAttrsForCopy(forHandle: srcHandle) }
        try copyFile(from: srcHandle, itemRelativePath: itemRelativePath, srcFileAttrs: srcCachedAttrs)
        try srcHandle.close()

        #endif  // canImport(WinSDK)

    }


    #if !canImport(WinSDK)
    fileprivate func copyFile(
        from srcHandle: borrowing UnsafeSystemHandle,
        itemRelativePath: FilePath,
        srcFileAttrs: consuming CachedCopySrcItemAttrs,
    ) throws(LowLevelError) {

        assert(srcFileAttrs.type == .regular, "srcFileAttrs must represent a regular file")

        let dstPath = dstAbsolutePath(of: itemRelativePath)

        let dstHandle: UnsafeSystemHandle
        let tmpDstPath: FilePath
        let shouldRename: Bool

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        switch (dstFileType, options.existingTarget) {
            case (.some(_), .error): 
                throw .init(kind: .alreadyExists)
            case (.some(_), .skip): 
                return
            case (.none, _): 
                let handle: UnsafeSystemHandle
                do {
                    // try to create directly
                    handle = try UnsafeSystemHandle.open(
                        at: dstPath,
                        openOptions: .init(access: .writeOnly(), creation: .assertMissing, noFollow: true),
                        creationPermissions: srcFileAttrs.permission
                    )
                } catch let error where error.kind == .alreadyExists && options.existingTarget == .skip {
                    return
                } catch let error where error.kind == .alreadyExists && options.existingTarget == .overwrite {
                    fallthrough     // if fail, fallthrough to copy to temp file 
                }
                tmpDstPath = dstPath
                shouldRename = false
                dstHandle = handle
            case (.some(.symlink), .overwrite), (.some(.regular), .overwrite):
                let tmpFileResult = try InternalFS.makeTmpFile(baseOn: dstPath)
                tmpDstPath = tmpFileResult.path
                dstHandle = tmpFileResult.takeHandle()
                shouldRename = true
            case (.some(.directory), .overwrite): 
                throw .init(kind: .isADirectory)
            case (.some(_), .overwrite): 
                throw .init(kind: .unsupported)
        }

        do {
            try InternalFS.copyRegularFileContent(from: srcHandle, to: dstHandle)
            if options.preserveSrcAccessTime {
                try? srcHandle.setFileTimes(access: srcFileAttrs.accessTime, modification: nil)
            }
            #if canImport(Darwin)
            try copyDarwinExtendedAttrs(fromHandle: srcHandle, toHandle: dstHandle)
            #endif
            try writeCachedItemAttrs(forHandle: dstHandle, members: [.fileTimes, .permissions], cachedAttrs: srcFileAttrs)
            if shouldRename {
                try InternalFS.rename(itemAt: tmpDstPath, to: dstPath)
            }
        } catch {
            try? InternalFS.unlink(fileAt: tmpDstPath)  // error of this operation is ignored
            (error.systemCode?.rawValue).map { errno = $0 }      // restore errno
            throw error
        }

        try writeCachedItemAttrs(forHandle: dstHandle, members: .flags, cachedAttrs: srcFileAttrs)

    }
    #endif


    // assume that the item at `itemRelativePath` directly points to a symlink (not a regular file or directory)
    mutating func copySymlink(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) throws(LowLevelError) {

        let srcPath = srcAbsolutePath(of: itemRelativePath)
        let srcAttrs = if let srcAttrs { srcAttrs } else { try cacheItemAttrsForCopy(forItemAt: srcPath) }
        assert(srcAttrs.type == .symlink, "srcAttrs must represent a symlink")

        #if canImport(WinSDK)

        if srcAttrs.attributes.contains(.windows.isDirectory) {
            try copyWindowDirSymlink(itemRelativePath: itemRelativePath, srcAttrs: srcAttrs)
        } else {
            try copyWindowFileOrSymlink(itemRelativePath: itemRelativePath, srcAttrs: srcAttrs)
        }

        #else 

        let dstPath = dstAbsolutePath(of: itemRelativePath)

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let dstTmpPath: FilePath
        let shouldRename: Bool

        switch (dstFileType, options.existingTarget) {
            case (.some(_), .error): 
                throw .init(kind: .alreadyExists)
            case (.some(_), .skip):
                return
            case (.some(.symlink), .overwrite), (.some(.regular), .overwrite), (.none, _):
                let targetPath = try InternalFS.readlink(fromSymlinkAt: srcPath)
                var trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                var created = false
                for _ in 0 ..< 24 {
                    do {
                        try InternalFS.symlink(dstPath: targetPath, linkPath: trialDstTmpPath)
                        created = true
                        break
                    } catch let error where error.kind == .alreadyExists {
                        trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                    }
                }
                guard created else {
                    throw .init(kind: .alreadyExists)
                }
                dstTmpPath = trialDstTmpPath
                shouldRename = true
            case (.some(.directory), .overwrite):
                throw .init(kind: .isADirectory)
            case (.some(_), .overwrite):
                throw .init(kind: .unsupported)
        }

        var srcMetadataHandle = nil as UnsafeSystemHandle?
        var dstMetadataHandle = nil as UnsafeSystemHandle?

        do {
            if options.preserveSrcAccessTime {
                try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil, followSymlink: false)
            }
            #if canImport(Darwin)
            srcMetadataHandle = try openMetadataHandle(forItemAt: srcPath)
            dstMetadataHandle = try openMetadataHandle(forItemAt: dstTmpPath)
            try copyDarwinExtendedAttrs(fromHandle: srcMetadataHandle!, toHandle: dstMetadataHandle!)
            try writeCachedItemAttrs(forHandle: dstMetadataHandle!, members: [.fileTimes, .permissions], cachedAttrs: srcAttrs)
            #else
            do {
                try writeCachedItemAttrs(forItemAt: dstTmpPath, members: [.fileTimes, .permissions], cachedAttrs: srcAttrs)
            } catch let error where error.kind == .unsupported {
                // ignore unsupported error on non-Darwin platforms
            }
            #endif
            if shouldRename {
                do {
                    try InternalFS.rename(itemAt: dstTmpPath, to: dstPath, replace: options.existingTarget == .overwrite)
                } catch let error where error.kind == .alreadyExists && options.existingTarget == .skip {
                    try? InternalFS.unlink(fileAt: dstTmpPath)
                    return
                }
            }
        } catch {
            try? InternalFS.unlink(fileAt: dstTmpPath)
            (error.systemCode?.rawValue).map { errno = $0 }
            throw error
        }

        #if canImport(Darwin)
        try writeCachedItemAttrs(forHandle: dstMetadataHandle!, members: .flags, cachedAttrs: srcAttrs)
        #elseif os(FreeBSD) || os(OpenBSD)
        try writeCachedItemAttrs(forItemAt: dstPath, members: .flags, cachedAttrs: srcAttrs)
        #endif

        try srcMetadataHandle?.close()
        try dstMetadataHandle?.close()

        #endif 

    } 


    #if canImport(WinSDK)
    fileprivate mutating func makeWindowsTmpFileSecurityDescriptor() throws(LowLevelError) -> WindowsAbsoluteSecurityDescriptor {
        let dacl = WindowsRawAcl(entries: [
            .init(permission: .genericAll, trustee: .init(sid: try getAndCacheCurrentUser().rawId, type: .unknown))
        ])
        return .init(control: .daclProtected, dacl: .some(dacl))
    }


    fileprivate func createDirSymlink(at linkPath: FilePath, dstPath: FilePath) throws(LowLevelError) {
        let flags = DWORD(SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE) | DWORD(SYMBOLIC_LINK_FLAG_DIRECTORY)
        try execThrowingCFunction {
            linkPath.withPlatformString { linkPtr in 
                dstPath.withPlatformString { dstPtr in 
                    CreateSymbolicLinkW(linkPtr, dstPtr, flags) == 1
                }
            }
        }
    }


    fileprivate func copyWindowDirSymlink(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(LowLevelError) {

        assert(
            srcAttrs.type == .symlink && srcAttrs.attributes.contains(.windows.isDirectory),
            "srcAttrs must represent a directory symlink"
        )

        let srcPath = srcAbsolutePath(of: itemRelativePath)
        let dstPath = dstAbsolutePath(of: itemRelativePath)

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let tmpDstPath: FilePath
        let shouldRename: Bool

        switch (dstFileType, options.existingTarget) {
            case (.some(_), .error): 
                throw .init(kind: .alreadyExists)
            case (.some(_), .skip):
                return
            case (.some(.symlink), .overwrite), (.some(.regular), .overwrite), (.none, _):
                let targetPath = try InternalFS.readlink(fromSymlinkAt: srcPath)
                var trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                var created = false
                for _ in 0 ..< 24 {
                    do {
                        try createDirSymlink(at: trialDstTmpPath, dstPath: targetPath)
                        created = true
                        break
                    } catch let error where error.kind == .alreadyExists {
                        trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                    }
                }
                guard created else {
                    throw .init(kind: .alreadyExists)
                }
                tmpDstPath = trialDstTmpPath
                shouldRename = true
            case (.some(.directory), .overwrite):
                throw .init(kind: .isADirectory)
            case (.some(_), .overwrite):
                throw .init(kind: .unsupported)
        }

        let dstMetadataHandle: UnsafeSystemHandle
        do {
            dstMetadataHandle = try openMetadataHandle(forItemAt: tmpDstPath)
        } catch {
            try? InternalFS.setFileAttributes(forItemAt: tmpDstPath, attributes: .windows.isNormal, followSymlink: false)
            try? InternalFS.unlink(fileAt: tmpDstPath)
            (error.systemCode?.rawValue).map { SetLastError($0) }    // restore errno
            throw error
        }

        do {
            if options.preserveSrcAccessTime {
                try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil, followSymlink: false)
            }
            try writeCachedItemAttrs(forHandle: dstMetadataHandle, members: [.fileTimes, .flags], cachedAttrs: srcAttrs)
            if shouldRename {
                do {
                    try InternalFS.rename(itemAt: tmpDstPath, to: dstPath, replace: options.existingTarget == .overwrite)
                } catch let error where error.kind == .alreadyExists && options.existingTarget == .skip {
                    try? dstMetadataHandle.setFileAttributes(.windows.isNormal)
                    try? InternalFS.unlink(fileAt: tmpDstPath)
                    return
                }
            }
        } catch {
            try? dstMetadataHandle.setFileAttributes(.windows.isNormal)
            try? InternalFS.unlink(fileAt: tmpDstPath)
            (error.systemCode?.rawValue).map { SetLastError($0) }    // restore errno
            throw error
        }

        try writeCachedItemAttrs(forHandle: dstMetadataHandle, members: .permissions, cachedAttrs: srcAttrs)
        try dstMetadataHandle.close()

    }


    fileprivate mutating func copyWindowFileOrSymlink(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(LowLevelError) {

        let srcPath = srcAbsolutePath(of: itemRelativePath)
        let dstPath = dstAbsolutePath(of: itemRelativePath)

        assert(
            (srcAttrs.type == .regular || srcAttrs.type == .symlink) 
            && !srcAttrs.attributes.contains(.windows.isDirectory), 
            "srcAttrs must represent a regular file or a symlink"
        )

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let tmpDstPath: FilePath
        let shouldRename: Bool
        var dstHandle: UnsafeSystemHandle? = nil

        func cleanTmpFile(tmpFileHandle: borrowing UnsafeSystemHandle?, tmpDstPath: FilePath) {
            if tmpFileHandle == nil {
                try? InternalFS.setFileAttributes(forItemAt: tmpDstPath, attributes: .windows.isNormal, followSymlink: false)
            } else {
                try? tmpFileHandle?.setFileAttributes(.windows.isNormal)
            }
            try? InternalFS.unlink(fileAt: tmpDstPath)      // error of this operation is ignored
        }

        switch (options.existingTarget, dstFileType) {
            case (.error, .some(_)): throw .init(kind: .alreadyExists)
            case (.skip, .some(_)): return
            case (.overwrite, .directory) : throw .init(kind: .isADirectory)
            case (.overwrite, .some(_)), (_, .none):
                var tmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                shouldRename = true
                var copied = false
                for _ in 0 ..< 24 {
                    do throws(LowLevelError) {
                        if srcAttrs.type == .regular && options.windowsPreserveExactDacl {
                            dstHandle = try UnsafeSystemHandle.open(
                                at: tmpPath,
                                openOptions: .init(
                                    access: .writeOnly(metadataOnly: true), 
                                    creation: .assertMissing, 
                                    noFollow: true,
                                    windowsShareMode: [.read, .write, .delete]
                                ),
                                creationPermissions: makeWindowsTmpFileSecurityDescriptor()
                            )
                            try InternalFS.copyRegularFileOrSymlink(from: srcPath, to: tmpPath, overwrite: true)
                        } else {
                            try InternalFS.copyRegularFileOrSymlink(from: srcPath, to: tmpPath, overwrite: false)
                        }
                        copied = true
                        break
                    } catch let error where error.kind == .alreadyExists { 
                        /* ignore */ 
                    } catch {
                        cleanTmpFile(tmpFileHandle: dstHandle, tmpDstPath: tmpPath)
                        (error.systemCode?.rawValue).map { SetLastError($0) }    // restore errno
                        throw error
                    }
                    tmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                }
                guard copied else {
                    // No cleanup here: reaching this point means every attempt failed with `.alreadyExists`,
                    // so we never created anything and whatever exists at `tmpPath` belongs to someone else.
                    throw .init(kind: .alreadyExists)
                }
                tmpDstPath = tmpPath
        }

        do {
            if dstHandle == nil {
                dstHandle = try openMetadataHandle(forItemAt: tmpDstPath)
            }
        } catch {
            cleanTmpFile(tmpFileHandle: dstHandle, tmpDstPath: tmpDstPath)
            (error.systemCode?.rawValue).map { SetLastError($0) }    // restore errno
            throw error
        }

        do {
            if options.preserveSrcAccessTime {
                try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil, followSymlink: false)
            }
            try writeCachedItemAttrs(forHandle: dstHandle!, members: [.fileTimes, .flags], cachedAttrs: srcAttrs)
            if shouldRename {
                do {
                    try InternalFS.rename(itemAt: tmpDstPath, to: dstPath, replace: options.existingTarget == .overwrite)
                } catch let error where error.kind == .alreadyExists && options.existingTarget == .skip {
                    cleanTmpFile(tmpFileHandle: dstHandle, tmpDstPath: tmpDstPath)
                    return
                }
            }
        } catch {
            cleanTmpFile(tmpFileHandle: dstHandle, tmpDstPath: tmpDstPath)
            (error.systemCode?.rawValue).map { SetLastError($0) }    // restore errno
            throw error
        }

        try writeCachedItemAttrs(forHandle: dstHandle!, members: .permissions, cachedAttrs: srcAttrs)
        try dstHandle?.close()

    }
    #endif 

}