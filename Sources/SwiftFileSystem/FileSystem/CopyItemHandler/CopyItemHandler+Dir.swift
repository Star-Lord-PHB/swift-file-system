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
                sd.addDaclEntries([
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
                                    sd.addDaclEntries([
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


    fileprivate struct RecursiveCopyDirStack: ~Copyable {

        enum DirCachedAttrs: ~Copyable {
            case full(CachedCopySrcItemAttrs)
            case skipped(srcAccessTime: FileTimeSpec)

            var srcAccessTime: FileTimeSpec {
                switch self {
                    case .full(let attrs): return attrs.accessTime
                    case .skipped(let accessTime): return accessTime
                }
            }

            var value: CachedCopySrcItemAttrs? {
                consuming get {
                    switch consume self {
                        case .full(let attrs): return attrs
                        case .skipped: return nil
                    }
                }
            }
        }

        private(set) var dirAttrsStack: UniqueArray<DirCachedAttrs?> = .init()
        private(set) var currDirRelativePath: FilePath = .init(root: nil)

        init(rootDirAttrs: consuming DirCachedAttrs?) {
            dirAttrsStack.append(rootDirAttrs)
        }

        var isEmpty: Bool { dirAttrsStack.isEmpty }
        var isNotEmpty: Bool { !isEmpty }

        mutating func push(name: String, attrs: consuming DirCachedAttrs?) {
            if self.isEmpty {
                assert(name.isEmpty, "Internal error: Unexpected non-empty name when pushing to an empty dirAttrsStack")
            } else {
                assert(!name.isEmpty, "Internal error: Unexpected empty name when pushing to a non-empty dirAttrsStack")
            }
            dirAttrsStack.append(attrs)
            currDirRelativePath.append(name)
        }

        mutating func popAndPerform<R: ~Copyable, E: Error>(
            _ action: (_ relativePath: FilePath, _ attrs: consuming DirCachedAttrs??
        ) throws(E) -> R) throws(E) -> R {
            let attrs = dirAttrsStack.popLast()
            defer { currDirRelativePath.removeLastComponent() }
            return try action(currDirRelativePath, attrs)
        }

        mutating func removeTopAndPerform<R: ~Copyable, E: Error>(
            _ action: (_ relativePath: FilePath, _ attrs: consuming DirCachedAttrs?) throws(E) -> R
        ) throws(E) -> R {
            assert(isNotEmpty, "Internal error: Unexpected empty dirAttrsStack when removing top")
            return try popAndPerform { (relativePath, attrs) throws(E) in
                return try action(relativePath, attrs!)
            }
        }

    }


    /// Recursively copies the directory tree rooted at the copy root.
    ///
    /// Every path handled here is relative to the copy roots, which is also what the traversal and the error
    /// report use; ``RecursiveCopyDirStack`` maintains the relative path of the directory currently being visited.
    mutating func copyDirectoryRecursive(srcAttrs: consuming CachedCopySrcItemAttrs) throws(RecursiveCopyAbortError) {

        assert(srcAttrs.type == .directory, "srcAttrs must represent a directory")

        var dirStack: RecursiveCopyDirStack

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

        // Traversing a source dir updates its access time, and the original one is only restored when the dir is
        // left. If the copy aborts halfway, every dir still on the stack has already been read but not yet
        // restored, so restore them here as a best effort. The destination times are deliberately not written:
        // that part of the destination tree is incomplete anyway.
        defer {
            if options.preserveSrcAccessTime {
                while dirStack.isNotEmpty {
                    dirStack.removeTopAndPerform { dirRelativePath, attrs in
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

        var enumerator = SkipableDirectoryEntryEnumerator(path: srcAbsolutePath(of: .init()))
        var skipCurrentDir = false

        dirIterLoop: while true {

            let entryResult = Result { () throws(LowLevelError) in
                try enumerator.next(skipCurrentDir: skipCurrentDir)
            }

            skipCurrentDir = false

            let entry: DirectoryEntry

            switch entryResult {
                case .failure(let err):
                    errorCollector.currentItemRelativePath = enumerator.currentDirRelativePath
                    try errorCollector.handleErrorAndAbort(err, operation: .copyContents)
                case .success(.none):
                    break dirIterLoop
                case .success(.entryError(let path, let error)):
                    errorCollector.currentItemRelativePath = path
                    try errorCollector.handleError(error, operation: .getSrcMetadata)
                    continue
                case .success(.leavingDir(let path, let error)), .success(.subTreeError(let path, let error as LowLevelError?)):
                    errorCollector.currentItemRelativePath = path
                    if let error {
                        try errorCollector.handleError(error, operation: .copyContents)
                    }
                    try dirStack.removeTopAndPerform(commitDirCopy)
                    continue
                case .success(.entry(let e)):
                    errorCollector.currentItemRelativePath = e.path
                    entry = e
            }

            // technically not necessary since the enumerator will skip '.' and '..' by default, just be defensive
            guard entry.path.lastComponent?.kind == .regular else { continue }

            // the enumerator's element paths are already relative to the source root, which is the copy root here
            let itemRelativePath = entry.path

            switch entry.type {
                case .regular:
                    try copyFile(itemRelativePath: itemRelativePath)
                case .symlink:
                    try copySymlink(itemRelativePath: itemRelativePath)
                case .directory:
                    switch try copyDir(itemRelativePath: itemRelativePath) {
                        case .copied(let srcAttrs):
                            dirStack.push(name: entry.name, attrs: .full(srcAttrs))
                        case .skipped(let srcAccessTime):
                            dirStack.push(name: entry.name, attrs: .skipped(srcAccessTime: srcAccessTime))
                        case .skippedNonDir:
                            skipCurrentDir = true
                        case .error:
                            skipCurrentDir = true
                    }
                default:
                    // sockets, fifos, devices, and (on Windows) reparse points that are not symlinks cannot be
                    // copied; report them per item so that the error strategy decides, instead of dropping them
                    // silently. This matches what `copyItem` reports when such an item is the root of the copy.
                    try errorCollector.handleError(.init(kind: .unsupported), operation: .copyContents)
            }

        }

        errorCollector.currentItemRelativePath = .init(root: nil)
        try dirStack.removeTopAndPerform(commitDirCopy)

        assert(dirStack.isEmpty, "Internal error: Unexpected non-empty dirAttrsStack after dir traversal")

    }

}
