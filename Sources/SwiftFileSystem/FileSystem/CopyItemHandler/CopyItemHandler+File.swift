import FileSystemCore
import struct SystemPackage.FilePath



extension CopyItemHandler {

    struct CopyFileContentContext: ~Copyable {

        #if canImport(WinSDK)
        let srcAbsPath: FilePath
        let dstAbsPath: FilePath
        var dstTmpAbsPath: FilePath? = nil
        var dstHandle: UnsafeSystemHandle? = nil
        #else
        let srcHandle: UnsafeSystemHandle
        let dstHandle: UnsafeSystemHandle
        let dstAbsPath: FilePath
        let dstTmpAbsPath: FilePath?
        #endif

        let srcAttrs: CachedCopySrcItemAttrs

        #if !canImport(WinSDK) && !canImport(Darwin)
        /// How the content is transferred. Starts with `copy_file_range`; a mechanism that turns out to be
        /// unusable for this pair of files before anything was transferred hands over to the next one.
        enum ContentCopyMechanism {
            case copyFileRange
            #if os(Linux) || os(Android)
            case sendfile
            #endif
            case readWrite
        }
        var mechanism: ContentCopyMechanism = .copyFileRange
        var srcOffset: off_t = 0
        var dstOffset: off_t = 0
        #endif


        consuming func close() throws(LowLevelError) {
            #if canImport(WinSDK)
            try dstHandle?.close()
            #else
            try srcHandle.close()
            try dstHandle.close()
            #endif
        }

    }
    

    mutating func startCopyFile(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) throws(RecursiveCopyAbortError) {

        switch self.state {
            case .copying(_, .none): 
                // valid state
                break
            case .copying(_, .some(_)):
                preconditionFailure("There is already an in-progress file copy")
            case .ended:
                preconditionFailure("Copy operation has already ended")
            default:
                preconditionFailure("Invalid State")
        }

        try checkCancellationRequest()

        defer {
            switch self.state {
                case .copying:
                    // valid state
                    break
                default:
                    preconditionFailure("Invalid State")
            }
        }

        #if canImport(WinSDK)

        let srcCachedAttrs = switch consume srcAttrs {
            case .some(let srcAttrs): srcAttrs
            case .none: try cacheItemAttrsForCopy(forItemAt: itemRelativePath)
        }
        guard let srcCachedAttrs else { return }
        assert(srcCachedAttrs.type == .regular, "srcCachedAttrs must represent a regular file")

        try startCopyFileWindows(itemRelativePath: itemRelativePath, srcAttrs: srcCachedAttrs)

        #else

        let path = srcAbsolutePath(of: itemRelativePath)

        let srcHandle = try errorCollector.execute(operation: .copyContents) {
            try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: true))
        }
        guard let srcHandle else { return }
        let srcCachedAttrs = switch consume srcAttrs {
            case .some(let srcAttrs): srcAttrs
            case .none: try cacheItemAttrsForCopy(forHandle: srcHandle)
        }
        guard let srcCachedAttrs else { return }
        try startCopyFilePosix(from: srcHandle, itemRelativePath: itemRelativePath, srcFileAttrs: srcCachedAttrs)

        #endif

    }


    @discardableResult
    mutating func copyFileStep() throws(RecursiveCopyAbortError) -> StepResult {
        #if canImport(WinSDK)
        return try copyFileStepWindows()
        #else
        return try copyFileStepPosix()
        #endif
    }

}


#if !canImport(WinSDK)

extension CopyItemHandler {

    fileprivate mutating func startCopyFilePosix(
        from srcHandle: consuming UnsafeSystemHandle,
        itemRelativePath: FilePath,
        srcFileAttrs: consuming CachedCopySrcItemAttrs,
    ) throws(RecursiveCopyAbortError) {

        assert(srcFileAttrs.type == .regular, "srcFileAttrs must represent a regular file")

        let dstPath = dstAbsolutePath(of: itemRelativePath)

        let dstHandle: UnsafeSystemHandle
        let tmpDstPath: FilePath?

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

        switch (dstFileType, options.existingTarget) {
            case (.some(_), .error): 
                try errorCollector.handleError(.init(kind: .alreadyExists), operation: .copyContents)
                return
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
                } catch {
                    try errorCollector.handleError(error, operation: .copyContents)
                    return
                }
                tmpDstPath = nil
                dstHandle = handle
            case (.some(.symlink), .overwrite), (.some(.regular), .overwrite):
                let tmpFileResult = try errorCollector.execute(operation: .copyContents) {
                    try InternalFS.makeTmpFile(baseOn: dstPath)
                }
                guard let tmpFileResult else { return }
                tmpDstPath = tmpFileResult.path
                dstHandle = tmpFileResult.takeHandle()
            case (.some(.directory), .overwrite): 
                try errorCollector.handleError(.init(kind: .isADirectory), operation: .copyContents)
                return
            case (.some(_), .overwrite): 
                try errorCollector.handleError(.init(kind: .unsupported), operation: .copyContents)
                return
        }

        let context = CopyFileContentContext(
            srcHandle: srcHandle,
            dstHandle: dstHandle,
            dstAbsPath: dstPath,
            dstTmpAbsPath: tmpDstPath,
            srcAttrs: srcFileAttrs
        )

        switch self.state.take() {
            case .copying(let dirCopyContext, .none):
                self.state = .copying(dirCopyContext: dirCopyContext, fileCopyContext: context)
            default:
                preconditionFailure("Invalid State")
        }

    }


    @discardableResult
    fileprivate mutating func copyFileStepPosix() throws(RecursiveCopyAbortError) -> StepResult {

        var context: CopyFileContentContext
        switch self.state.take() {
            case .copying(let dirCopyContext, .some(let fileCopyContext)):
                self.state = .copying(dirCopyContext: dirCopyContext)
                context = fileCopyContext
            default: 
                preconditionFailure("Invalid State")
        }

        do {
            try checkCancellationRequest()
        } catch {
            try? InternalFS.unlink(fileAt: context.dstTmpAbsPath ?? context.dstAbsPath)
            throw error
        }

        let stepResult = Result { () throws(LowLevelError) in
            try copyFileContentStep(&context)
        }

        switch stepResult {
            case .failure(let error): 
                try? InternalFS.unlink(fileAt: context.dstTmpAbsPath ?? context.dstAbsPath)
                try errorCollector.handleError(error, operation: .copyContents)
                return .completed
            case .success(.paused):
                switch self.state.take() {
                    case .copying(let dirCopyContext, .none):
                        self.state = .copying(dirCopyContext: dirCopyContext, fileCopyContext: context)
                    default: 
                        preconditionFailure("Invalid State")
                }
                return .paused
            case .success(.completed):
                break
        }

        if options.preserveSrcAccessTime {
            try? context.srcHandle.setFileTimes(access: context.srcAttrs.accessTime, modification: nil)
        }

        do {
            #if canImport(Darwin)
            do {
                try Self.copyDarwinExtendedAttrs(fromHandle: context.srcHandle, toHandle: context.dstHandle)
            } catch { try errorCollector.handleError(error, operation: .copyExtendedAttributes) }
            do {
                try Self.copyDarwinACL(fromHandle: context.srcHandle, toHandle: context.dstHandle)
            } catch { try errorCollector.handleError(error, operation: .copyDarwinACL) }
            #endif
            try writeCachedItemAttrs(forHandle: context.dstHandle, members: [.fileTimes, .permissions], cachedAttrs: context.srcAttrs)
        } catch {
            try? InternalFS.unlink(fileAt: context.dstTmpAbsPath ?? context.dstAbsPath)  // error of this operation is ignored
            throw error
        }

        do {
            if let dstTmpAbsPath = context.dstTmpAbsPath {
                try InternalFS.rename(itemAt: dstTmpAbsPath, to: context.dstAbsPath)
            }
        } catch {
            try? InternalFS.unlink(fileAt: context.dstTmpAbsPath ?? context.dstAbsPath)  // error of this operation is ignored
            try errorCollector.handleError(error, operation: .copyContents)
            return .completed
        }

        try writeCachedItemAttrs(forHandle: context.dstHandle, members: .flags, cachedAttrs: context.srcAttrs)

        do {
            try context.close()
        } catch { try errorCollector.handleError(error, operation: .releaseResources) }

        return .completed

    }

}

#else

extension CopyItemHandler {

    fileprivate mutating func startCopyFileWindows(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(RecursiveCopyAbortError) {

        let srcPath = srcAbsolutePath(of: itemRelativePath)
        let dstPath = dstAbsolutePath(of: itemRelativePath)

        assert(
            (srcAttrs.type == .regular || srcAttrs.type == .symlink) 
            && !srcAttrs.attributes.contains(.windows.isDirectory), 
            "srcAttrs must represent a regular file or a symlink"
        )

        let dstFileType = try? InternalFS.type(ofItemAt: dstPath)

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
                break
        }

        let context = CopyFileContentContext(
            srcAbsPath: srcPath,
            dstAbsPath: dstPath,
            srcAttrs: srcAttrs
        )

        switch self.state.take() {
            case .copying(let dirCopyContext, .none):
                self.state = .copying(dirCopyContext: dirCopyContext, fileCopyContext: context)
            default:
                preconditionFailure("Invalid State")
        }

    }



    @discardableResult
    fileprivate mutating func copyFileStepWindows() throws(RecursiveCopyAbortError) -> StepResult {

        func cleanTmpFile(tmpFileHandle: borrowing UnsafeSystemHandle?, tmpDstPath: FilePath) {
            if tmpFileHandle == nil {
                try? InternalFS.setFileAttributes(forItemAt: tmpDstPath, attributes: .windows.isNormal, followSymlink: false)
            } else {
                try? tmpFileHandle?.setFileAttributes(.windows.isNormal)
            }
            try? InternalFS.unlink(fileAt: tmpDstPath)      // error of this operation is ignored
        }

        var context: CopyFileContentContext
        switch self.state.take() {
            case .copying(let dirCopyContext, .some(let fileCopyContext)):
                self.state = .copying(dirCopyContext: dirCopyContext)
                context = fileCopyContext
            default: 
                preconditionFailure("Invalid State")
        }

        do {
            try checkCancellationRequest()
        } catch {
            if let dstTmpAbsPath = context.dstTmpAbsPath {
                cleanTmpFile(tmpFileHandle: context.dstHandle, tmpDstPath: dstTmpAbsPath)
            }
            throw error
        }

        let stepResult = Result { () throws(LowLevelError) in
            try copyFileContentStep(&context)
        }

        switch stepResult {
            case .failure(let error): 
                if let dstTmpAbsPath = context.dstTmpAbsPath {
                    cleanTmpFile(tmpFileHandle: context.dstHandle, tmpDstPath: dstTmpAbsPath)
                }
                if error.kind == .cancelled && cancellationToken.isCancelled {
                    throw .cancelled
                }
                try errorCollector.handleError(error, operation: .copyContents)
                return .completed
            case .success(.paused):
                switch self.state.take() {
                    case .copying(let dirCopyContext, .none):
                        self.state = .copying(dirCopyContext: dirCopyContext, fileCopyContext: context)
                    default: 
                        preconditionFailure("Invalid State")
                }
                return .paused
            case .success(.completed):
                break
        }

        guard let dstTmpAbsPath = context.dstTmpAbsPath else {
            preconditionFailure("dstTmpAbsPath is still nil on successful completion")
        }

        if options.preserveSrcAccessTime {
            try? InternalFS.setFileTimes(forItemAt: context.srcAbsPath, access: context.srcAttrs.accessTime, modification: nil, followSymlink: false)
        }

        var dstHandle = context.dstHandle.take()

        do {
            do {
                if dstHandle == nil {
                    dstHandle = .some(try openMetadataHandle(forItemAt: dstTmpAbsPath))
                }
            } catch {
                try errorCollector.handleError(error, operation: .copyMetadata)
            }
            if dstHandle != nil {
                try writeCachedItemAttrs(forHandle: dstHandle!, members: [.fileTimes, .flags], cachedAttrs: context.srcAttrs)
            }
        } catch {
            cleanTmpFile(tmpFileHandle: dstHandle, tmpDstPath: dstTmpAbsPath)
            throw error
        }

        do {
            try InternalFS.rename(itemAt: dstTmpAbsPath, to: context.dstAbsPath, replace: options.existingTarget == .overwrite)
        } catch {
            cleanTmpFile(tmpFileHandle: dstHandle, tmpDstPath: dstTmpAbsPath)
            if !(error.kind == .alreadyExists && options.existingTarget == .skip) {
                try errorCollector.handleError(error, operation: .copyContents)
            }
            return .completed
        }

        if dstHandle != nil {
            try writeCachedItemAttrs(forHandle: dstHandle!, members: .permissions, cachedAttrs: context.srcAttrs)
        }
        do {
            try dstHandle?.close()
            try context.close()
        } catch { try errorCollector.handleError(error, operation: .releaseResources) }

        return .completed

    }

}

#endif



extension CopyItemHandler {

    fileprivate mutating func copyFileContentStep(
        _ context: inout CopyFileContentContext
    ) throws(LowLevelError) -> StepResult {

        #if canImport(Darwin)

        if fileContentCopyBuffer == nil {
            fileContentCopyBuffer = .init(count: 1024 * 1024)
        }

        let bytesRead = try fileContentCopyBuffer!.withUnsafeMutableBytes { (ptr) throws(LowLevelError) in
            try context.srcHandle.read(into: ptr)
        }

        if bytesRead == 0 { return .completed }

        try fileContentCopyBuffer!.withUnsafeBytes { (ptr) throws(LowLevelError) in
            _ = try context.dstHandle.write(contentsOf: ptr.prefix(Int(bytesRead)))
        }

        return .paused

        #elseif !canImport(WinSDK)

        // A mechanism only hands over to the next one while nothing has been transferred yet: the offsets kept
        // here and the file positions the later mechanisms rely on agree only at zero. The cases are ordered by
        // preference, so handing over is a `fallthrough` into the next case.
        switch context.mechanism {

            case .copyFileRange:
                // in-kernel copy with filesystem acceleration (reflink, server-side copy) where available; the
                // C shim reports ENOSYS for every "not for this pair of files" outcome (ENOSYS, EXDEV, EINVAL,
                // EOPNOTSUPP), including any cross-filesystem copy since Linux 5.19
                let byteCopied = copy_file_range(
                    context.srcHandle.unsafeRawHandle, &context.srcOffset, context.dstHandle.unsafeRawHandle, &context.dstOffset,
                    8 * 1024 * 1024, 0
                )
                if byteCopied < 0 && errno == ENOSYS && context.srcOffset == 0 {
                    #if os(Linux) || os(Android)
                    context.mechanism = .sendfile
                    #else
                    context.mechanism = .readWrite
                    #endif
                    fallthrough
                }
                // EINTR (interrupted) can be ignored and simply retry
                guard byteCopied >= 0 else {
                    if errno == EINTR {
                        return .paused
                    }
                    try LowLevelError.assertError()
                }
                return byteCopied > 0 ? .paused : .completed

            #if os(Linux) || os(Android)
            case .sendfile:
                // in-kernel copy through the splice path, which also works across filesystems. The destination is
                // written at its file position, still 0 at this point. Sources without splice support (procfs,
                // sysfs) report EINVAL.
                let byteCopied = sendfile(
                    context.dstHandle.unsafeRawHandle, context.srcHandle.unsafeRawHandle, &context.srcOffset, 8 * 1024 * 1024
                )
                if byteCopied < 0 && (errno == EINVAL || errno == ENOSYS) && context.srcOffset == 0 {
                    context.mechanism = .readWrite
                    fallthrough
                }
                guard byteCopied >= 0 else {
                    if errno == EINTR {
                        return .paused
                    }
                    try LowLevelError.assertError()
                }
                return byteCopied > 0 ? .paused : .completed
            #endif

            case .readWrite:
                // plain copy through a user-space buffer, for the pairs of files the kernel cannot copy itself
                if fileContentCopyBuffer == nil {
                    fileContentCopyBuffer = .init(count: 1024 * 1024)
                }
                let bytesRead = try fileContentCopyBuffer!.withUnsafeMutableBytes { (ptr) throws(LowLevelError) in
                    try context.srcHandle.read(into: ptr)
                }
                guard bytesRead > 0 else { return .completed }
                try fileContentCopyBuffer!.withUnsafeBytes { (ptr) throws(LowLevelError) in
                    _ = try context.dstHandle.write(contentsOf: ptr.prefix(Int(bytesRead)))
                }
                return .paused

        }

        #else

        var copied = false

        let callbackArg = UnsafeUnownedMutableRawPointer(unownedPointer: cancellationToken.unsafeFlagPtr.unsafeRawPtr)
        let callback = { _, _, _, _, _, _, _, _, argPtr in
            if let argPtr {
                let flag = argPtr.assumingMemoryBound(to: CFSAtomicFlag.self)
                return cfsAtomicFlagIsSet(flag) ? DWORD(PROGRESS_CANCEL) : DWORD(PROGRESS_CONTINUE)
            }
            return DWORD(PROGRESS_CONTINUE)
        } as LPPROGRESS_ROUTINE

        for _ in 0 ..< 24 {

            context.dstTmpAbsPath = InternalFS.makeRandomTmpName(baseOn: context.dstAbsPath)

            do throws(LowLevelError) {

                if options.windowsPreserveExactDacl {
                    context.dstHandle = try UnsafeSystemHandle.open(
                        at: context.dstTmpAbsPath!,
                        openOptions: .init(
                            access: .writeOnly(metadataOnly: true), 
                            creation: .assertMissing, 
                            noFollow: true,
                            windowsShareMode: [.read, .write, .delete]
                        ),
                        creationPermissions: makeWindowsTmpFileSecurityDescriptor()
                    )
                    try InternalFS.copyRegularFileOrSymlink(
                        from: context.srcAbsPath, to: context.dstTmpAbsPath!, overwrite: true, 
                        callbackArg: callbackArg, callback: callback
                    )
                } else {
                    try InternalFS.copyRegularFileOrSymlink(
                        from: context.srcAbsPath, to: context.dstTmpAbsPath!, overwrite: false, 
                        callbackArg: callbackArg, callback: callback
                    )
                }

                copied = true
                break

            } catch let error where error.kind == .alreadyExists { 
                /* ignore */ 
            }

        }

        guard copied else {
            context.dstTmpAbsPath = nil
            throw .init(kind: .alreadyExists)
        }

        return .completed

        #endif

    }


    #if canImport(WinSDK)
    fileprivate mutating func makeWindowsTmpFileSecurityDescriptor() throws(LowLevelError) -> WindowsAbsoluteSecurityDescriptor {
        let dacl = WindowsRawAcl(entries: [
            .init(permission: .genericAll, trustee: .init(sid: try getAndCacheCurrentUser().rawId, type: .unknown))
        ])
        return .init(control: .daclProtected, dacl: .acl(dacl))
    }
    #endif

}
