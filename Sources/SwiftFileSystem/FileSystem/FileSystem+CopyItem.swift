import SystemPackage
import FileSystemCore


extension FileSystem {

    public func copyItem<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>(
        at srcPath: FilePath, 
        to dstPath: FilePath, 
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption = .overwrite, 
        symlinkOption: FileOperationOptions.CopyItemSymlinkOption = .copyLink,
        errorStrategy: ErrorStrategy = .abortOnError
    ) throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.ReturnedError {

        var errorCollector = RecursiveCopyErrorCollector(srcRootPath: srcPath, dstRootPath: dstPath, strategy: errorStrategy)

        do throws(RecursiveCopyAbortError) {

            // resolve symlink first if needed
            let resolvedSrcPath: FilePath
            do {
                resolvedSrcPath = symlinkOption == .copyTarget ? try InternalFS.realpath(of: srcPath) : srcPath
            } catch {
                try errorCollector.handleErrorAndAbort(error, itemRelativePath: .init())
            }

            try _copyItemNoFollow(from: resolvedSrcPath, to: dstPath, overwrite: targetExistOption, errorCollector: &errorCollector)

        } catch { /* Abort errors are not necessary to be handled */ }

        return try errorStrategy.reportError(errorCollector.report.value)

    }

}



extension FileSystem {

    fileprivate struct RecursiveCopyAbortError: Error {}


    fileprivate struct CachedCopySrcItemAttrs: ~Copyable {

        // this type is used instead of ``InternalFS.InternalFileTimes`` since we don't need ctime
        struct CachedFileTimes {
            let accessTime: FileTimeSpec
            let modificationTime: FileTimeSpec
            let creationTime: FileTimeSpec?
        }

        let info: FileInfo

        var type: FileKind { info.type }

        var fileTimes: CachedFileTimes {
            .init(
                accessTime: info.times.lastAccess, 
                modificationTime: info.times.lastModification, 
                creationTime: info.times.creation
            )
        }

        var accessTime: FileTimeSpec { info.times.lastAccess }
        var modificationTime: FileTimeSpec { info.times.lastModification }
        var statusChangeTime: FileTimeSpec { info.times.lastChange }
        var creationTime: FileTimeSpec? { info.times.creation }

        #if canImport(Glibc) || canImport(Musl)
        // on Linux, inode flags are not available for symlinks
        let attributes: LinuxInodeFlags?
        #else
        // on other platforms, file flags should always be available
        var attributes: PlatformFileAttributes { info.attributes }
        #endif 

        #if canImport(WinSDK)
        let securityDescriptor: WindowsSelfRelativeSecurityDescriptor
        #else 
        let permission: FilePermissions
        #endif

        // MARK: TODO: add platform specific extended attributes if necessary
    }


    fileprivate func _cacheItemAttrsForCopy(forHandle handle: borrowing UnsafeSystemHandle) throws(LowLevelError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        let info = try handle.fileInfo()
        let sd = try handle.securityInfo(.dacl)

        return .init(info: info, securityDescriptor: sd)

        #else 

        let stat = try handle.fstat()

        #if canImport(Glibc) || canImport(Musl)

        let flags = try handle.fileInodeFlags()
        return .init(info: .init(stat: stat), attributes: flags, permission: .init(rawValue: stat.st_mode))

        #else

        return .init(info: .init(stat: stat), permission: .init(rawValue: stat.st_mode))

        #endif

        #endif 

    }


    fileprivate func _cacheItemAttrsForCopy(forItemAt path: FilePath) throws(LowLevelError) -> CachedCopySrcItemAttrs {

        #if canImport(WinSDK)

        let info = try InternalFS.getFileInfo(forItemAt: path, followSymlink: false)
        let sd = try InternalFS.getSecurityInfo(forItemAt: path, members: .dacl, followSymlink: false)

        return .init(info: info, securityDescriptor: sd)

        #else 

        let stat = try InternalFS.ulstat(path)

        #if canImport(Glibc) || canImport(Musl)

        let flags = if FileKind(mode: stat.st_mode) != .symlink {
            try InternalFS.readFileInodeFlags(forItemAt: path, followSymlink: false)
        } else {
            nil as LinuxInodeFlags?
        }

        return .init(info: .init(stat: stat), attributes: flags, permission: .init(rawValue: stat.st_mode))

        #else

        return .init(info: .init(stat: stat), permission: .init(rawValue: stat.st_mode))

        #endif 

        #endif 

    }


    fileprivate func _writeCachedItemAttrsWithoutFileTime(
        forHandle handle: borrowing UnsafeSystemHandle, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {

        #if canImport(WinSDK)

        try handle.setFileAttributes(cachedAttrs.attributes)
        try handle.setSecurityInfo(.dacl, dacl: cachedAttrs.securityDescriptor.dacl.value, sacl: nil, owner: nil, group: nil)

        #else 

        try handle.setPosixPermissions(cachedAttrs.permission)

        #if canImport(Glibc) || canImport(Musl)
        if let flags = cachedAttrs.attributes {
            try handle.setFileInodeFlags(flags)
        }
        #else
        try handle.setFileAttributes(cachedAttrs.attributes)
        #endif

        #endif 

    }


    fileprivate func _writeCachedItemAttrsWithoutFileTime(
        forItemAt path: FilePath, 
        cachedAttrs: borrowing CachedCopySrcItemAttrs
    ) throws(LowLevelError) {
        
        #if canImport(WinSDK)

        try InternalFS.setFileAttributes(forItemAt: path, attributes: cachedAttrs.attributes, followSymlink: false)

        try InternalFS.setSecurityInfo(
            forItemAt: path, 
            setting: .dacl, 
            dacl: cachedAttrs.securityDescriptor.dacl.value, 
            sacl: nil, owner: nil, group: nil,
            followSymlink: false
        )

        #else

        do {
            try InternalFS.setPosixPermissions(forItemAt: path, permissions: cachedAttrs.permission, followSymlink: false)
        } catch let error where error.kind == .unsupported {
            // ignore unsupported error on setting permission
        }
        
        #if canImport(Glibc) || canImport(Musl)
        if let flags = cachedAttrs.attributes {
            do {
                try InternalFS.setFileInodeFlags(forItemAt: path, flags: flags, followSymlink: false)
            } catch let error where error.kind == .unsupported || error.kind == .isADirectory {
                // ignore unsupported error and is a dir error on setting inode flags
            }
        }
        #else
        try InternalFS.setFileAttributes(forItemAt: path, attributes: cachedAttrs.attributes, followSymlink: false)
        #endif

        #endif 

    }

}



extension FileSystem {

    fileprivate struct RecursiveCopyErrorCollector<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol> {
        enum LazyReport {
            case none(srcRootPath: FilePath, dstRootPath: FilePath)
            case some(RecursiveCopyErrorReport)
            var value: RecursiveCopyErrorReport? {
                switch self {
                    case .none: return nil
                    case .some(let report): return report
                }
            }
            mutating func append(_ error: RecursiveCopySingleItemError) {
                switch self {
                    case .none(let srcRootPath, let dstRootPath):
                        self = .some(.init(srcRootPath: srcRootPath, dstRootPath: dstRootPath, errors: [error]))
                    case .some(var report):
                        report.append(error)
                        self = .some(report)
                }
            }
        }
        var report: LazyReport
        let strategy: ErrorStrategy
        private(set) var aborted: Bool = false
        init(srcRootPath: FilePath, dstRootPath: FilePath, strategy: ErrorStrategy) {
            self.report = .none(srcRootPath: srcRootPath, dstRootPath: dstRootPath)
            self.strategy = strategy
        }
        mutating func handleError(_ error: LowLevelError, itemRelativePath: FilePath) throws(RecursiveCopyAbortError)  {
            assert(aborted == false, "Should not handle further error after aborted")
            let (collect, abort) = strategy.handleError(lowLevelError: error, itemRelativePath: itemRelativePath)
            if collect {
                report.append(.init(itemRelativePath: itemRelativePath, code: error.systemCode, kind: error.kind))
            }
            if abort {
                aborted = true  
                throw .init()
            }
        }
        mutating func handleErrorAndAbort(_ error: LowLevelError, itemRelativePath: FilePath) throws(RecursiveCopyAbortError) -> Never {
            assert(aborted == false, "Should not handle further error after aborted")
            defer { aborted = true }
            try handleError(error, itemRelativePath: itemRelativePath)
            throw .init()
        }
    }

}



extension FileSystem {

    fileprivate func _copyItemNoFollow<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>(
        from srcPath: FilePath, 
        to dstPath: FilePath, 
        overwrite: FileOperationOptions.CopyTargetExistOption,
        errorCollector: inout RecursiveCopyErrorCollector<ErrorStrategy>
    ) throws(RecursiveCopyAbortError) {
        
        let srcAttrs: CachedCopySrcItemAttrs
        do {
            srcAttrs = try _cacheItemAttrsForCopy(forItemAt: srcPath)
        } catch {
            try errorCollector.handleErrorAndAbort(error, itemRelativePath: .init())
        }
        let type = srcAttrs.type

        switch type {
            case .regular:
                do {
                    try _copyFile(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)
                } catch {
                    try errorCollector.handleErrorAndAbort(error, itemRelativePath: .init())
                }
            case .symlink:
                do {
                    try _copySymlink(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)
                } catch {
                    try errorCollector.handleErrorAndAbort(error, itemRelativePath: .init())
                }
            case .directory:
                try _copyDirectoryRecursive(from: srcPath, to: dstPath, overwrite: overwrite, errorCollector: &errorCollector, srcAttrs: srcAttrs)
            default:
                try errorCollector.handleErrorAndAbort(.init(kind: .unsupported), itemRelativePath: .init())
        }

    }


    // assume that the srcPath directly points to a regular file (not a directory or symlink)
    fileprivate func _copyFile(
        from srcPath: FilePath, 
        to dstPath: FilePath, 
        overwrite: FileOperationOptions.CopyTargetExistOption, 
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) throws(LowLevelError) {

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


    #if !canImport(WinSDK)
    fileprivate func _copyFile(
        from srcHandle: borrowing UnsafeSystemHandle, 
        to dstPath: FilePath, 
        overwrite: FileOperationOptions.CopyTargetExistOption, 
        srcPath: FilePath, 
        srcFileAttrs: consuming CachedCopySrcItemAttrs,
    ) throws(LowLevelError) {

        assert(srcFileAttrs.type == .regular, "srcFileAttrs must represent a regular file")

        let dstHandle: UnsafeSystemHandle
        let tmpDstPath: FilePath
        let shouldRename: Bool

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        switch (dstFileType, overwrite) {
            case (.some(_), .error): 
                throw .init(kind: .alreadyExists)
            case (.none, .error): 
                tmpDstPath = dstPath
                shouldRename = false
                dstHandle = try UnsafeSystemHandle.open(
                    at: dstPath,
                    openOptions: .init(access: .writeOnly(), creation: .assertMissing, noFollow: true)
                )
            case (.some(_), .skip): 
                return
            case (.none, .overwrite), (.none, .skip): 
                let handle: UnsafeSystemHandle
                do {
                    // try to create directly
                    handle = try UnsafeSystemHandle.open(
                        at: dstPath,
                        openOptions: .init(access: .writeOnly(), creation: .assertMissing, noFollow: true)
                    )
                } catch let error where error.kind == .alreadyExists && overwrite == .skip {
                    return
                } catch let error where error.kind == .alreadyExists && overwrite == .overwrite {
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
            #if canImport(Darwin)
            try InternalFS.copyRegularFileWithMetaNoTimes(from: srcHandle, to: dstHandle)
            #else
            try InternalFS.copyRegularFileContent(from: srcHandle, to: dstHandle)
            #endif
            try? srcHandle.setFileTimes(access: srcFileAttrs.accessTime, modification: nil)
            #if !canImport(Darwin)
            try _writeCachedItemAttrsWithoutFileTime(forHandle: dstHandle, cachedAttrs: srcFileAttrs)
            #endif
            try dstHandle.setFileTimes(access: srcFileAttrs.accessTime, modification: srcFileAttrs.modificationTime, creation: srcFileAttrs.creationTime)
            if shouldRename {
                try InternalFS.rename(itemAt: tmpDstPath, to: dstPath)
            }
        } catch {
            try? InternalFS.unlink(fileAt: tmpDstPath)  // error of this operation is ignored
            (error.systemCode?.rawValue).map { errno = $0 }      // restore errno
            throw error
        }

    }
    #endif


    // assume that the srcPath directly points to a symlink (not a regular file or directory)
    fileprivate func _copySymlink(
        from srcPath: FilePath, 
        to dstPath: FilePath, 
        overwrite: FileOperationOptions.CopyTargetExistOption, 
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) throws(LowLevelError) {

        let srcAttrs = if let srcAttrs { srcAttrs } else { try _cacheItemAttrsForCopy(forItemAt: srcPath) }
        assert(srcAttrs.type == .symlink, "srcAttrs must represent a symlink")

        #if canImport(WinSDK)

        try _copyFileOrSymlink(from: srcPath, to: dstPath, overwrite: overwrite, srcAttrs: srcAttrs)

        #else 

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let dstTmpPath: FilePath
        let shouldRename: Bool

        switch (dstFileType, overwrite) {
            case (.some(_), .error): 
                throw .init(kind: .alreadyExists)
            case (.none, .error):
                #if canImport(Darwin)
                try InternalFS.copyItemWithMetaNoTimes(from: srcPath, to: dstPath, overwrite: false)
                #else 
                let targetPath = try InternalFS.readlink(fromSymlinkAt: srcPath)
                try InternalFS.symlink(dstPath: targetPath, linkPath: dstPath)
                #endif
                dstTmpPath = dstPath
                shouldRename = false
            case (.some(_), .skip):
                return
            case (.some(.symlink), .overwrite), (.some(.regular), .overwrite), (.none, .overwrite), (.none, .skip):
                #if !canImport(Darwin)
                let targetPath = try InternalFS.readlink(fromSymlinkAt: srcPath)
                #endif
                var trialDstTmpPath = InternalFS.makeRandomTmpName(baseOn: dstPath)
                var created = false
                for _ in 0 ..< 24 {
                    do {
                        #if canImport(Darwin) 
                        try InternalFS.copyItemWithMetaNoTimes(from: srcPath, to: trialDstTmpPath, overwrite: false)
                        #else 
                        try InternalFS.symlink(dstPath: targetPath, linkPath: trialDstTmpPath)
                        #endif
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

        do {
            try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil, followSymlink: false)
            #if canImport(Darwin)
            try InternalFS.copyFileMetaNoTimes(from: srcPath, to: dstTmpPath)
            #else
            try _writeCachedItemAttrsWithoutFileTime(forItemAt: dstTmpPath, cachedAttrs: srcAttrs)
            #endif
            try InternalFS.setFileTimes(forItemAt: dstTmpPath, access: srcAttrs.accessTime, modification: srcAttrs.modificationTime, creation: srcAttrs.creationTime, followSymlink: false)
            if shouldRename {
                try InternalFS.rename(itemAt: dstTmpPath, to: dstPath)
            }
        } catch {
            try? InternalFS.unlink(fileAt: dstTmpPath)
            (error.systemCode?.rawValue).map { errno = $0 }
            throw error
        }

        #endif 

    } 


    #if canImport(WinSDK)
    fileprivate func _copyFileOrSymlink(
        from srcPath: FilePath,
        to dstPath: FilePath,
        overwrite: FileOperationOptions.CopyTargetExistOption,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(LowLevelError) {

        assert(
            srcAttrs.type == .regular || srcAttrs.type == .symlink, 
            "srcAttrs must represent a regular file or a symlink"
        )

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        let tmpDstPath: FilePath
        let shouldRename: Bool

        switch (overwrite, dstFileType) {
            case (.error, .some(_)): throw .init(kind: .alreadyExists)
            case (.skip, .some(_)): return
            case (.error, .none), (.skip, .none): 
                tmpDstPath = dstPath
                shouldRename = false
                do {
                    try InternalFS.copyRegularFileOrSymlink(from: srcPath, to: tmpDstPath, overwrite: false)
                } catch let error where error.kind == .alreadyExists && overwrite == .skip {
                    return
                }
            case (.overwrite, .directory) : throw .init(kind: .isADirectory)
            case (.overwrite, _):
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
                    throw .init(kind: .alreadyExists)
                }
                tmpDstPath = tmpPath
        }

        do {
            try? InternalFS.setFileTimes(forItemAt: srcPath, access: srcAttrs.accessTime, modification: nil, followSymlink: false)
            try _writeCachedItemAttrsWithoutFileTime(forItemAt: tmpDstPath, cachedAttrs: srcAttrs)
            try InternalFS.setFileTimes(forItemAt: tmpDstPath, access: srcAttrs.accessTime, modification: srcAttrs.modificationTime, creation: srcAttrs.creationTime, followSymlink: false)
            if shouldRename {
                try InternalFS.rename(itemAt: tmpDstPath, to: dstPath)
            }
        } catch {
            try? InternalFS.unlink(fileAt: tmpDstPath)      // error of this operation is ignored
            error.systemCode?.rawValue.map { SetLastError($0) }    // restore errno
            throw error
        }

    }
    #endif 


    fileprivate enum DirCopyResult: ~Copyable {
        case copied(CachedCopySrcItemAttrs?)
        case skipped(FileTimeSpec?)
        case skippedNonDir
        case error(LowLevelError)
    }


    fileprivate func _copyDir(
        srcPath: FilePath, 
        dstPath: FilePath, 
        overwrite: FileOperationOptions.CopyTargetExistOption, 
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) -> DirCopyResult {
        assert(srcAttrs == nil || srcAttrs?.type == .directory, "srcAttrs must represent a directory if provided")
        do {
            #if canImport(Darwin)
            try InternalFS.copyItemWithMetaNoTimes(from: srcPath, to: dstPath, overwrite: false)
            return .copied(srcAttrs ?? (try? _cacheItemAttrsForCopy(forItemAt: srcPath)))
            #else 
            try InternalFS.mkdir(at: dstPath, permissions: nil)
            guard let srcAttrs = srcAttrs ?? (try? _cacheItemAttrsForCopy(forItemAt: srcPath)) else {
                return .copied(nil)
            }
            try? _writeCachedItemAttrsWithoutFileTime(forItemAt: dstPath, cachedAttrs: srcAttrs)
            return .copied(srcAttrs)
            #endif
        } catch where error.kind == .alreadyExists {
            do throws(LowLevelError) {
                switch overwrite {
                    case .error: throw error
                    case .skip: 
                        guard let type = try? InternalFS.type(ofItemAt: dstPath) else {
                            throw .unknown
                        }
                        if type == .directory {
                            return .skipped(try? InternalFS.getFileTimes(fromItemAt: dstPath, followSymlink: false).lastAccess)
                        } else {
                            return .skippedNonDir
                        }
                    case .overwrite:
                        guard let type = try? InternalFS.type(ofItemAt: dstPath) else { 
                            throw .unknown
                        }
                        if type == .directory {
                            #if canImport(Darwin)
                            try? InternalFS.copyFileMetaNoTimes(from: srcPath, to: dstPath)
                            return .copied(srcAttrs ?? (try? _cacheItemAttrsForCopy(forItemAt: srcPath)))
                            #else
                            guard let srcAttrs = srcAttrs ?? (try? _cacheItemAttrsForCopy(forItemAt: srcPath)) else {
                                return .copied(nil)
                            }
                            try? _writeCachedItemAttrsWithoutFileTime(forItemAt: dstPath, cachedAttrs: srcAttrs)
                            return .copied(srcAttrs)
                            #endif
                        } else {
                            throw .init(kind: .notADirectory)
                        }
                }
            } catch {
                return .error(error)
            }
        } catch {
            return .error(error)
        } 
    }


    /// Store the file times to be copied to the destination dir and the original access time of the source dir to be restored later
    fileprivate struct DirFileTimesItem {
        let fileTimesToCopy: CachedCopySrcItemAttrs.CachedFileTimes?
        let cachedSrcAccessTime: FileTimeSpec
        init(fileTimesToCopy: CachedCopySrcItemAttrs.CachedFileTimes? = nil, cachedSrcAccessTime: FileTimeSpec) {
            self.fileTimesToCopy = fileTimesToCopy
            self.cachedSrcAccessTime = cachedSrcAccessTime
        }
        init(fileTimesToCopy: CachedCopySrcItemAttrs.CachedFileTimes) {
            self.init(fileTimesToCopy: fileTimesToCopy, cachedSrcAccessTime: fileTimesToCopy.accessTime)
        }
    }


    fileprivate func _copyDirectoryRecursive<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>(
        from srcPath: FilePath, 
        to dstPath: FilePath, 
        overwrite: FileOperationOptions.CopyTargetExistOption, 
        errorCollector: inout RecursiveCopyErrorCollector<ErrorStrategy>,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(RecursiveCopyAbortError) {

        assert(srcAttrs.type == .directory, "srcAttrs must represent a directory")

        var dirFileTimesStack = [DirFileTimesItem?]()

        do throws(LowLevelError) {
            switch _copyDir(srcPath: srcPath, dstPath: dstPath, overwrite: overwrite, srcAttrs: srcAttrs) {
                case .copied(let srcAttrs):             // dst not exist or dst is sucessfully overwritten
                    dirFileTimesStack.append((srcAttrs?.fileTimes).map { .init(fileTimesToCopy: $0) })
                case .skipped(let srcAccessTime):       // dst is an existing directory and overwrite is .skip
                    dirFileTimesStack.append(srcAccessTime.map { .init(cachedSrcAccessTime: $0) })
                case .skippedNonDir:                    // dst is an existing non-directory and overwrite is .skip
                    return
                case .error(let error): 
                    throw error
            }
        } catch {
            try errorCollector.handleErrorAndAbort(error, itemRelativePath: .init())
        }

        var enumerator = SkipableDirectoryEntryEnumerator(path: srcPath, doStat: true)
        var skipCurrentDir = false

        while true {

            let enumerationElement: SkipableDirectoryEntryEnumerator.Element
            do {
                guard let e = try enumerator.next(skipCurrentDir: skipCurrentDir) else { break }
                enumerationElement = e
            } catch {
                try errorCollector.handleErrorAndAbort(error, itemRelativePath: .init(root: nil, enumerator.currentDirPathComponents))
            }

            skipCurrentDir = false

            var entry: DirectoryEntry

            switch enumerationElement {
                case .entryError(let path, let error), .subTreeError(let path, let error):
                    try errorCollector.handleError(error, itemRelativePath: path)
                    continue
                case .leavingDir(let path, let error):
                    if let error {
                        try errorCollector.handleError(error, itemRelativePath: path)
                    }
                    assert(dirFileTimesStack.isEmpty == false, "Internal error: Unexpected empty dirFileTimesStack during dir traversal")
                    guard let item = dirFileTimesStack.popLast().flatMap(\.self) else { continue }
                    if let times = item.fileTimesToCopy {
                        try? InternalFS.setFileTimes(
                            forItemAt: dstPath.appending(path.components), 
                            access: times.accessTime, 
                            modification: times.modificationTime, 
                            creation: times.creationTime,
                            followSymlink: false
                        )
                    }
                    try? InternalFS.setFileTimes(forItemAt: srcPath.appending(path.components), access: item.cachedSrcAccessTime, modification: nil, followSymlink: false)
                    continue
                case .entry(let e): 
                    entry = e   
            }

            // technically not necessary since the enumerator will skip '.' and '..' by default, just be defensive
            guard entry.path.lastComponent?.kind == .regular else { continue }

            do throws(LowLevelError) {
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
                        switch _copyDir(srcPath: srcPath.appending(entry.path.components), dstPath: dstPath.appending(entry.path.components), overwrite: overwrite) {
                            case .copied(let srcAttrs):
                                dirFileTimesStack.append((srcAttrs?.fileTimes).map { .init(fileTimesToCopy: $0) })
                            case .skipped(let srcAccessTime): 
                                dirFileTimesStack.append(srcAccessTime.map { .init(cachedSrcAccessTime: $0) })
                            case .skippedNonDir:
                                skipCurrentDir = true
                            case .error(let error):
                                skipCurrentDir = true
                                throw error 
                        }
                    default: break
                }
            } catch {
                try errorCollector.handleError(error, itemRelativePath: entry.path)
            }

        }

        do {
            assert(dirFileTimesStack.isEmpty == false, "Internal error: Unexpected empty dirFileTimesStack during dir traversal")
            if let item = dirFileTimesStack.popLast().flatMap(\.self) {
                if let times = item.fileTimesToCopy {
                    try? InternalFS.setFileTimes(forItemAt: dstPath, access: times.accessTime, modification: times.modificationTime, creation: times.creationTime, followSymlink: false)
                }
                try? InternalFS.setFileTimes(forItemAt: srcPath, access: item.cachedSrcAccessTime, modification: nil, followSymlink: false)
            }
        }

        assert(dirFileTimesStack.isEmpty, "Internal error: Unexpected non-empty dirFileTimesStack after dir traversal")

    }

}
