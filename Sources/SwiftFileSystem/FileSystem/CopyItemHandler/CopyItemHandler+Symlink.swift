import FileSystemCore
import struct SystemPackage.FilePath



extension CopyItemHandler {

    mutating func copySymlink(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) throws(RecursiveCopyAbortError) {

        try checkCancellationRequest()

        let srcAttrs = switch consume srcAttrs {
            case .some(let srcAttrs): srcAttrs
            case .none: try cacheItemAttrsForCopy(forItemAt: itemRelativePath)
        }
        guard let srcAttrs else { return }
        assert(srcAttrs.type == .symlink, "srcAttrs must represent a symlink")

        #if canImport(WinSDK)

        if srcAttrs.attributes.contains(.windows.isDirectory) {
            try copyWindowDirSymlink(itemRelativePath: itemRelativePath, srcAttrs: srcAttrs)
        } else {
            try copyWindowSymlink(itemRelativePath: itemRelativePath, srcAttrs: srcAttrs)
        }

        #else

        try copySymlinkPosix(itemRelativePath: itemRelativePath, srcAttrs: srcAttrs)

        #endif

    }

}



#if !canImport(WinSDK)
extension CopyItemHandler {

    // assume that the item at `itemRelativePath` directly points to a symlink (not a regular file or directory)
    fileprivate mutating func copySymlinkPosix(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(RecursiveCopyAbortError) {

        let srcPath = srcAbsolutePath(of: itemRelativePath)
        let dstPath = dstAbsolutePath(of: itemRelativePath)

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let dstTmpPath: FilePath

        switch (dstFileType, options.existingTarget) {
            case (.some(_), .error): 
                try errorCollector.handleError(.init(kind: .alreadyExists), operation: .copyContents)
                return
            case (.some(_), .skip):
                return
            case (.some(.symlink), .overwrite), (.some(.regular), .overwrite), (.none, _):
                let targetPath = try errorCollector.execute(operation: .copyContents) {
                    try InternalFS.readlink(fromSymlinkAt: srcPath)
                }
                guard let targetPath else { return }
                var trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                var created = false
                for _ in 0 ..< 24 {
                    do {
                        try InternalFS.symlink(dstPath: targetPath, linkPath: trialDstTmpPath)
                        created = true
                        break
                    } catch let error where error.kind == .alreadyExists {
                        trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                    } catch {
                        try errorCollector.handleError(error, operation: .copyContents)
                        return
                    }
                }
                guard created else {
                    try errorCollector.handleError(.init(kind: .alreadyExists), operation: .copyContents)
                    return
                }
                dstTmpPath = trialDstTmpPath
            case (.some(.directory), .overwrite):
                try errorCollector.handleError(.init(kind: .isADirectory), operation: .copyContents)
                return
            case (.some(_), .overwrite):
                try errorCollector.handleError(.init(kind: .unsupported), operation: .copyContents)
                return
        }

        if options.preserveSrcAccessTime {
            try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil, followSymlink: false)
        }

        var srcMetadataHandle = nil as UnsafeSystemHandle?
        var dstMetadataHandle = nil as UnsafeSystemHandle?

        do {
            #if canImport(Darwin)
            do {
                dstMetadataHandle = try openMetadataHandle(forItemAt: dstTmpPath)
            } catch {
                try errorCollector.handleError(error, operation: .copyMetadata)
            }
            do {
                if dstMetadataHandle != nil {
                    srcMetadataHandle = try openMetadataHandle(forItemAt: srcPath)
                }
            } catch {
                try errorCollector.handleError(error, operation: .copyExtendedAttributes)
                try errorCollector.handleError(error, operation: .copyDarwinACL)
            }
            if srcMetadataHandle != nil && dstMetadataHandle != nil {
                try errorCollector.execute(operation: .copyExtendedAttributes) {
                    try Self.copyDarwinExtendedAttrs(fromHandle: srcMetadataHandle!, toHandle: dstMetadataHandle!)
                }
                try errorCollector.execute(operation: .copyDarwinACL) {
                    try Self.copyDarwinACL(fromHandle: srcMetadataHandle!, toHandle: dstMetadataHandle!)
                }
            }
            if dstMetadataHandle != nil {
                try writeCachedItemAttrs(
                    forHandle: dstMetadataHandle!, members: [.fileTimes, .permissions], cachedAttrs: srcAttrs
                )
            }
            #else
            do {
                try writeCachedFileTimes(forItemAt: dstTmpPath, cachedAttrs: srcAttrs)
            } catch {
                if error.kind != .unsupported {
                    try errorCollector.handleError(error, operation: .copyTimes)
                }
            }
            do {
                try writeCachedPermissions(forItemAt: dstTmpPath, cachedAttrs: srcAttrs)
            } catch {
                if error.kind != .unsupported {
                    try errorCollector.handleError(error, operation: .copyPermissions)
                }
            }
            #endif
        } catch {
            try? InternalFS.unlink(fileAt: dstTmpPath)
            throw error
        }

        do {
            try InternalFS.rename(itemAt: dstTmpPath, to: dstPath, replace: options.existingTarget == .overwrite)
        } catch {
            try? InternalFS.unlink(fileAt: dstTmpPath)
            if !(error.kind == .alreadyExists && options.existingTarget == .skip) {
                try errorCollector.handleError(error, operation: .copyContents)
            }
            return
        }

        #if canImport(Darwin)
        if dstMetadataHandle != nil {
            try writeCachedItemAttrs(forHandle: dstMetadataHandle!, members: .flags, cachedAttrs: srcAttrs)
        }
        #else
        try writeCachedItemAttrs(forItemAt: dstPath, members: .flags, cachedAttrs: srcAttrs)
        #endif

        do {
            try srcMetadataHandle?.close()
        } catch { try errorCollector.handleError(error, operation: .releaseResources) }

        do {
            try dstMetadataHandle?.close()
        } catch { try errorCollector.handleError(error, operation: .releaseResources) }

    }

}
#endif



#if canImport(WinSDK)
extension CopyItemHandler {

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


    fileprivate mutating func copyWindowDirSymlink(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(RecursiveCopyAbortError) {

        assert(
            srcAttrs.type == .symlink && srcAttrs.attributes.contains(.windows.isDirectory),
            "srcAttrs must represent a directory symlink"
        )

        let srcPath = srcAbsolutePath(of: itemRelativePath)
        let dstPath = dstAbsolutePath(of: itemRelativePath)

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let tmpDstPath: FilePath

        switch (dstFileType, options.existingTarget) {
            case (.some(_), .error): 
                try errorCollector.handleError(.init(kind: .alreadyExists), operation: .copyContents)
                return
            case (.some(_), .skip):
                return
            case (.some(.symlink), .overwrite), (.some(.regular), .overwrite), (.none, _):
                let targetPath = try errorCollector.execute(operation: .copyContents) {
                    try InternalFS.readlink(fromSymlinkAt: srcPath)
                }
                guard let targetPath else { return }
                var trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                var created = false
                for _ in 0 ..< 24 {
                    do {
                        try createDirSymlink(at: trialDstTmpPath, dstPath: targetPath)
                        created = true
                        break
                    } catch let error where error.kind == .alreadyExists {
                        trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                    } catch {
                        try errorCollector.handleError(error, operation: .copyContents)
                        return
                    }
                }
                guard created else {
                    try errorCollector.handleError(.init(kind: .alreadyExists), operation: .copyContents)
                    return
                }
                tmpDstPath = trialDstTmpPath
            case (.some(.directory), .overwrite):
                try errorCollector.handleError(.init(kind: .isADirectory), operation: .copyContents)
                return
            case (.some(_), .overwrite):
                try errorCollector.handleError(.init(kind: .unsupported), operation: .copyContents)
                return
        }

        if options.preserveSrcAccessTime {
            try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil, followSymlink: false)
        }

        func cleanTmpLink(handle: borrowing UnsafeSystemHandle?) {
            if handle == nil {
                try? InternalFS.setFileAttributes(forItemAt: tmpDstPath, attributes: .windows.isNormal, followSymlink: false)
            } else {
                try? handle?.setFileAttributes(.windows.isNormal)
            }
            try? InternalFS.remove(itemAt: tmpDstPath)
        }

        var dstMetadataHandle: UnsafeSystemHandle? = nil

        do {
            do {
                dstMetadataHandle = try openMetadataHandle(forItemAt: tmpDstPath)
            } catch {
                try errorCollector.handleError(error, operation: .copyMetadata)
            }
            if dstMetadataHandle != nil {
                try writeCachedItemAttrs(
                    forHandle: dstMetadataHandle!, members: [.fileTimes, .flags], cachedAttrs: srcAttrs
                )
            }
        } catch {
            cleanTmpLink(handle: dstMetadataHandle)
            throw error
        }

        do {
            try InternalFS.rename(itemAt: tmpDstPath, to: dstPath, replace: options.existingTarget == .overwrite)
        } catch let error {
            cleanTmpLink(handle: dstMetadataHandle)
            if !(error.kind == .alreadyExists && options.existingTarget == .skip) {
                try errorCollector.handleError(error, operation: .copyContents)
            }
            return
        }

        if dstMetadataHandle != nil {
            try writeCachedItemAttrs(forHandle: dstMetadataHandle!, members: .permissions, cachedAttrs: srcAttrs)
        }
        do {
            try dstMetadataHandle?.close()
        } catch { try errorCollector.handleError(error, operation: .releaseResources) }

    }


    fileprivate mutating func copyWindowSymlink(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(RecursiveCopyAbortError) {

        let srcPath = srcAbsolutePath(of: itemRelativePath)
        let dstPath = dstAbsolutePath(of: itemRelativePath)

        assert(
            srcAttrs.type == .symlink && !srcAttrs.attributes.contains(.windows.isDirectory), 
            "srcAttrs must represent a non-directory symlink"
        )

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let tmpDstPath: FilePath

        func cleanTmpFile(tmpFileHandle: borrowing UnsafeSystemHandle?, tmpDstPath: FilePath) {
            if tmpFileHandle == nil {
                try? InternalFS.setFileAttributes(forItemAt: tmpDstPath, attributes: .windows.isNormal, followSymlink: false)
            } else {
                try? tmpFileHandle?.setFileAttributes(.windows.isNormal)
            }
            try? InternalFS.unlink(fileAt: tmpDstPath)      // error of this operation is ignored
        }

        switch (options.existingTarget, dstFileType) {
            case (.error, .some(_)): 
                try errorCollector.handleError(.init(kind: .alreadyExists), operation: .copyContents)
                return
            case (.skip, .some(_)): return
            case (.overwrite, .directory): 
                try errorCollector.handleError(.init(kind: .isADirectory), operation: .copyContents)
                return
            case (.overwrite, .unknown): 
                try errorCollector.handleError(.init(kind: .unsupported), operation: .copyContents)
                return
            case (.overwrite, .some(_)), (_, .none):
                var tmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                var copied = false
                for _ in 0 ..< 24 {
                    do throws(LowLevelError) {
                        try InternalFS.copyRegularFileOrSymlink(from: srcPath, to: tmpPath, overwrite: false, callbackArg: nil, callback: nil)
                        copied = true
                        break
                    } catch let error where error.kind == .alreadyExists { 
                        /* ignore */ 
                    } catch {
                        cleanTmpFile(tmpFileHandle: nil, tmpDstPath: tmpPath)
                        try errorCollector.handleError(error, operation: .copyContents)
                        return
                    }
                    tmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                }
                guard copied else {
                    // No cleanup here: reaching this point means every attempt failed with `.alreadyExists`,
                    // so we never created anything and whatever exists at `tmpPath` belongs to someone else.
                    try errorCollector.handleError(.init(kind: .alreadyExists), operation: .copyContents)
                    return
                }
                tmpDstPath = tmpPath
        }

        if options.preserveSrcAccessTime {
            try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil, followSymlink: false)
        }

        var dstHandle: UnsafeSystemHandle? = nil

        do {
            do {
                dstHandle = try openMetadataHandle(forItemAt: tmpDstPath)
            } catch {
                try errorCollector.handleError(error, operation: .copyMetadata)
            }
            if dstHandle != nil {
                try writeCachedItemAttrs(forHandle: dstHandle!, members: [.fileTimes, .flags], cachedAttrs: srcAttrs)
            }
        } catch {
            cleanTmpFile(tmpFileHandle: dstHandle, tmpDstPath: tmpDstPath)
            throw error
        }

        do {
            try InternalFS.rename(itemAt: tmpDstPath, to: dstPath, replace: options.existingTarget == .overwrite)
        } catch {
            cleanTmpFile(tmpFileHandle: dstHandle, tmpDstPath: tmpDstPath)
            if !(error.kind == .alreadyExists && options.existingTarget == .skip) {
                try errorCollector.handleError(error, operation: .copyContents)
            }
            return
        }

        if dstHandle != nil {
            try writeCachedItemAttrs(forHandle: dstHandle!, members: .permissions, cachedAttrs: srcAttrs)
        }
        do {
            try dstHandle?.close()
        } catch { try errorCollector.handleError(error, operation: .releaseResources) }

    }

}
#endif
