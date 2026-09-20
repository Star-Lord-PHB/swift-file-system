import FileSystemCore
import BasicContainers
import struct SystemPackage.FilePath



extension CopyItemHandler {

    fileprivate enum DirCopyResult: ~Copyable {
        case copied(CachedCopySrcItemAttrs)
        case skipped(srcAccessTime: FileTimeSpec)
        case skippedNonDir
        case error
    }


    fileprivate mutating func copyDir(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) throws(RecursiveCopyAbortError) -> DirCopyResult {
        let dstPath = dstAbsolutePath(of: itemRelativePath)
        let srcAttrsInternal = switch consume srcAttrs {
            case .some(let srcAttrs): srcAttrs
            case .none: try cacheItemAttrsForCopy(forItemAt: itemRelativePath)
        }
        guard let srcAttrsInternal else { return .error }
        guard srcAttrsInternal.type == .directory else {
            preconditionFailure("srcAttrs must represent a directory")
        }
        do throws(LowLevelError) {
            #if canImport(WinSDK)
            if options.windowsPreserveExactDacl, var sd = srcAttrsInternal.securityDescriptor?.makeAbsolute() {
                sd.dacl.addEntries([
                    .init(permission: .genericAll, trustee: .init(sid: try getAndCacheCurrentUser().rawId, type: .unknown))
                ])
                try InternalFS.mkdir(at: dstPath, permissions: sd.view)
            } else {
                try InternalFS.mkdir(at: dstPath, permissions: nil)
            }
            #else
            // u+rwx keeps the directory writable while its children are copied in; the exact
            // source permissions are committed when the directory is left.
            let permission = [srcAttrsInternal.permission, .ownerReadWriteExecute] as FilePermissions
            try InternalFS.mkdir(at: dstPath, permissions: permission)
            try InternalFS.setPosixPermissions(forItemAt: dstPath, permissions: permission, followSymlink: false)
            #endif
            return .copied(srcAttrsInternal)
        } catch where error.kind == .alreadyExists {
            switch options.existingTarget {
                case .error: 
                    try errorCollector.handleError(error, operation: .copyContents)
                    return .error
                case .skip: 
                    guard let type = try? InternalFS.type(ofItemAt: dstPath) else {
                        try errorCollector.handleError(.init(kind: .unknown), operation: .copyContents)
                        return .error
                    }
                    if type == .directory {
                        return .skipped(srcAccessTime: srcAttrsInternal.accessTime)
                    } else {
                        return .skippedNonDir
                    }
                case .overwrite:
                    guard let type = try? InternalFS.type(ofItemAt: dstPath) else { 
                        try errorCollector.handleError(.init(kind: .unknown), operation: .copyContents)
                        return .error
                    }
                    if type == .directory {
                        #if canImport(WinSDK)
                        if options.windowsPreserveExactDacl {
                            do throws(LowLevelError) {
                                if var sd = srcAttrsInternal.securityDescriptor?.makeAbsolute() {
                                    sd.dacl.addEntries([
                                        .init(permission: .genericAll, trustee: .init(sid: try getAndCacheCurrentUser().rawId, type: .unknown))
                                    ])
                                    let securityInformation = srcAttrsInternal.sdControl?.contains(.daclProtected) == true
                                        ? DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION) 
                                        : DWORD(DACL_SECURITY_INFORMATION)
                                    try execThrowingCFunction {
                                        dstPath.withPlatformString { pathPtr in
                                            SetFileSecurityW(pathPtr, securityInformation, sd.psd.unsafeRawPtr)
                                        }
                                    }
                                }
                            } catch {
                                try errorCollector.handleError(error, operation: .copyContents)
                                return .error
                            }
                        }
                        #else
                        do {
                            try InternalFS.setPosixPermissions(
                                forItemAt: dstPath,
                                permissions: [srcAttrsInternal.permission, .ownerReadWriteExecute],
                                followSymlink: false
                            )
                        } catch {
                            try errorCollector.handleError(error, operation: .copyContents)
                            return .error
                        }
                        #endif
                        return .copied(srcAttrsInternal)
                    } else {
                        try errorCollector.handleError(.init(kind: .notADirectory), operation: .copyContents)
                        return .error
                    }
            }
        } catch {
            try errorCollector.handleError(error, operation: .copyContents)
            return .error
        } 
    }


    struct RecursiveCopyDirStack: ~Copyable {

        enum DirCachedAttrs: ~Copyable {
            case full(CachedCopySrcItemAttrs)
            case skipped(srcAccessTime: FileTimeSpec)

            fileprivate var srcAccessTime: FileTimeSpec {
                switch self {
                    case .full(let attrs): return attrs.accessTime
                    case .skipped(let accessTime): return accessTime
                }
            }

            fileprivate var value: CachedCopySrcItemAttrs? {
                consuming get {
                    switch consume self {
                        case .full(let attrs): return attrs
                        case .skipped: return nil
                    }
                }
            }
        }

        fileprivate private(set) var dirAttrsStack: UniqueArray<DirCachedAttrs?> = .init()
        fileprivate private(set) var currDirRelativePath: FilePath = .init(root: nil)

        fileprivate init(rootDirAttrs: consuming DirCachedAttrs?) {
            dirAttrsStack.append(rootDirAttrs)
        }

        var isEmpty: Bool { dirAttrsStack.isEmpty }
        var isNotEmpty: Bool { !isEmpty }

        fileprivate mutating func push(name: String, attrs: consuming DirCachedAttrs?) {
            if self.isEmpty {
                assert(name.isEmpty, "Internal error: Unexpected non-empty name when pushing to an empty dirAttrsStack")
            } else {
                assert(!name.isEmpty, "Internal error: Unexpected empty name when pushing to a non-empty dirAttrsStack")
            }
            dirAttrsStack.append(attrs)
            currDirRelativePath.append(name)
        }

        fileprivate mutating func popAndPerform<R: ~Copyable, E: Error>(
            _ action: (_ relativePath: FilePath, _ attrs: consuming DirCachedAttrs??
        ) throws(E) -> R) throws(E) -> R {
            let attrs = dirAttrsStack.popLast()
            defer { currDirRelativePath.removeLastComponent() }
            return try action(currDirRelativePath, attrs)
        }

        fileprivate mutating func removeTopAndPerform<R: ~Copyable, E: Error>(
            _ action: (_ relativePath: FilePath, _ attrs: consuming DirCachedAttrs?) throws(E) -> R
        ) throws(E) -> R {
            assert(isNotEmpty, "Internal error: Unexpected empty dirAttrsStack when removing top")
            return try popAndPerform { (relativePath, attrs) throws(E) in
                return try action(relativePath, attrs!)
            }
        }

    }

}



extension CopyItemHandler {

    struct CopyDirContext: ~Copyable {

        fileprivate var dirStack: RecursiveCopyDirStack
        fileprivate var enumerator: DirectoryEntryRecursiveEnumerator
        fileprivate var skipCurrentDir: Bool = false

    }


    mutating func startCopyDirectoryRecursive(srcAttrs: consuming CachedCopySrcItemAttrs) throws(RecursiveCopyAbortError) {

        switch self.state {
            case .copying(.none, .none):
                // valid state
                break
            case .copying(_, .some(_)): 
                preconditionFailure("there is already an in-progress file copy")
            case .copying(.some(_), .none):
                preconditionFailure("there is already an in-progress directory copy")
            default: 
                preconditionFailure("Invalid State")
        }

        try checkCancellationRequest()

        assert(srcAttrs.type == .directory, "srcAttrs must represent a directory")

        let dirStack: RecursiveCopyDirStack

        switch try copyDir(itemRelativePath: .init(), srcAttrs: srcAttrs) {
            case .copied(let srcAttrs):             // dst not exist or dst is sucessfully overwritten
                dirStack = .init(rootDirAttrs: .full(srcAttrs))
            case .skipped(let srcAccessTime):       // dst is an existing directory and overwrite is .skip
                dirStack = .init(rootDirAttrs: .skipped(srcAccessTime: srcAccessTime))
            case .skippedNonDir:                    // dst is an existing non-directory and overwrite is .skip
                return
            case .error: 
                return
        }

        let context = CopyDirContext(dirStack: dirStack, enumerator: .init(path: srcAbsolutePath(of: .init())))

        switch self.state.take() {
            case .copying(.none, .none):
                self.state = .copying(dirCopyContext: context, fileCopyContext: .none)
            default:
                preconditionFailure("Invalid State")
        }

    }


    @discardableResult
    mutating func copyDirectoryRecursiveStep() throws(RecursiveCopyAbortError) -> StepResult {

        var context: CopyDirContext
        var hasInProgressFileCopy = false
        switch self.state.take() {
            case .copying(.some(let dirCopyContext), let fileCopyContext):
                hasInProgressFileCopy = fileCopyContext != nil
                context = dirCopyContext
                self.state = .copying(fileCopyContext: fileCopyContext)
            case .copying(.none, .none):
                preconditionFailure("No in-progress directory copy context")
            default: 
                preconditionFailure("Invalid State")
        }

        let result = Result { () throws(RecursiveCopyAbortError) in
            if hasInProgressFileCopy {
                try copyFileStep()
            } else {
                try _copyDirectoryRecursiveStep(context: &context)
            }
        }

        switch result {
            case .success(.completed) where hasInProgressFileCopy:
                fallthrough
            case .success(.paused):
                switch self.state.take() {
                    case .copying(.none, let fileCopyContext): 
                        self.state = .copying(dirCopyContext: context, fileCopyContext: fileCopyContext)
                    default:
                        preconditionFailure("Invalid State")
                }
                return .paused
            default:
                cleanCopyDirContext(context)
                return try result.get()
        }

    }


    fileprivate func cleanCopyDirContext(_ context: consuming CopyDirContext) {
        if options.preserveSrcAccessTime {
            while context.dirStack.isNotEmpty {
                context.dirStack.removeTopAndPerform { dirRelativePath, attrs in
                    guard let srcAccessTime = attrs?.srcAccessTime else { return }
                    try? InternalFS.setFileTimes(
                        forItemAt: srcAbsolutePath(of: dirRelativePath),
                        access: srcAccessTime,
                        modification: nil,
                        followSymlink: false
                    )
                }
            }
        }
    }


    private mutating func _copyDirectoryRecursiveStep(context: inout CopyDirContext) throws(RecursiveCopyAbortError) -> StepResult {

        try checkCancellationRequest()

        func commitDirCopy(dirRelativePath: FilePath, attrs: consuming RecursiveCopyDirStack.DirCachedAttrs?) throws(RecursiveCopyAbortError) {
            guard let attrs else { return }
            if options.preserveSrcAccessTime {
                try? InternalFS.setFileTimes(
                    forItemAt: srcAbsolutePath(of: dirRelativePath),
                    access: attrs.srcAccessTime,
                    modification: nil,
                    followSymlink: false
                )
            }
            if let attrs = attrs.value {
                var dstHandle: UnsafeSystemHandle?
                do {
                    dstHandle = try openMetadataHandle(forItemAt: dstAbsolutePath(of: dirRelativePath))
                } catch {
                    try errorCollector.handleError(error, operation: .copyMetadata)
                }
                #if canImport(Darwin)
                var srcHandle: UnsafeSystemHandle?
                do {
                    if dstHandle != nil {
                        srcHandle = try openMetadataHandle(forItemAt: srcAbsolutePath(of: dirRelativePath))
                    }
                } catch {
                    try errorCollector.handleError(error, operation: .copyExtendedAttributes)
                    try errorCollector.handleError(error, operation: .copyDarwinACL)
                }
                if srcHandle != nil && dstHandle != nil {
                    try errorCollector.execute(operation: .copyExtendedAttributes) {
                        try Self.copyDarwinExtendedAttrs(fromHandle: srcHandle!, toHandle: dstHandle!)
                    }
                    try errorCollector.execute(operation: .copyDarwinACL) {
                        try Self.copyDarwinACL(fromHandle: srcHandle!, toHandle: dstHandle!)
                    }
                }
                #endif
                if dstHandle != nil {
                    try writeCachedItemAttrs(forHandle: dstHandle!, members: .all, cachedAttrs: attrs)
                }
                do {
                    try dstHandle?.close()
                } catch { try errorCollector.handleError(error, operation: .releaseResources) }
                #if canImport(Darwin)
                do {
                    try srcHandle?.close()
                } catch { try errorCollector.handleError(error, operation: .releaseResources) }
                #endif
            }
        }

        let entryResult = Result { () throws(LowLevelError) in
            try context.enumerator.next(skipCurrentDir: context.skipCurrentDir)
        }

        context.skipCurrentDir = false

        let entry: DirectoryEntry

        switch entryResult {
            case .failure(let err):
                errorCollector.currentItemRelativePath = context.enumerator.currentDirRelativePath
                try errorCollector.handleErrorAndAbort(err, operation: .copyContents)
            case .success(.none):
                // Finishing the root dir
                errorCollector.currentItemRelativePath = .init(root: nil)
                try context.dirStack.removeTopAndPerform(commitDirCopy)
                assert(context.dirStack.isEmpty, "Internal error: Unexpected non-empty dirAttrsStack after dir traversal")
                return .completed
            case .success(.entryError(let path, let error)):
                errorCollector.currentItemRelativePath = path
                try errorCollector.handleError(error, operation: .getSrcMetadata)
                return .paused
            case .success(.leavingDir(let path, let error)), .success(.subTreeError(let path, let error as LowLevelError?)):
                errorCollector.currentItemRelativePath = path
                if let error {
                    try errorCollector.handleError(error, operation: .copyContents)
                }
                try context.dirStack.removeTopAndPerform(commitDirCopy)
                return .paused
            case .success(.entry(let e)):
                errorCollector.currentItemRelativePath = e.path
                entry = e
        }

        // technically not necessary since the enumerator will skip '.' and '..' by default, just be defensive
        guard entry.path.lastComponent?.kind == .regular else { return .paused }

        // the enumerator's element paths are already relative to the source root, which is the copy root here
        let itemRelativePath = entry.path

        switch entry.type {
            case .regular:
                try startCopyFile(itemRelativePath: itemRelativePath)
            case .symlink:
                try copySymlink(itemRelativePath: itemRelativePath)
            case .directory:
                switch try copyDir(itemRelativePath: itemRelativePath) {
                    case .copied(let srcAttrs):
                        context.dirStack.push(name: entry.name, attrs: .full(srcAttrs))
                    case .skipped(let srcAccessTime):
                        context.dirStack.push(name: entry.name, attrs: .skipped(srcAccessTime: srcAccessTime))
                    case .skippedNonDir:
                        context.skipCurrentDir = true
                    case .error:
                        context.skipCurrentDir = true
                }
            default:
                // sockets, fifos, devices, and (on Windows) reparse points that are not symlinks cannot be
                // copied; report them per item so that the error strategy decides, instead of dropping them
                // silently. This matches what `copyItem` reports when such an item is the root of the copy.
                try errorCollector.handleError(.init(kind: .unsupported), operation: .copyContents)
        }

        return .paused

    }

}
