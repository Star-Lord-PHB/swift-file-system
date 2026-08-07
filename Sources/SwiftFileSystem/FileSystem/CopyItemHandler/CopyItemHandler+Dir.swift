import FileSystemCore
import BasicContainers
import struct SystemPackage.FilePath



extension CopyItemHandler {

    fileprivate enum DirCopyResult: ~Copyable {
        case copied(CachedCopySrcItemAttrs)
        case skipped(srcAccessTime: FileTimeSpec)
        case skippedNonDir
        case error(LowLevelError)
    }


    fileprivate mutating func copyDir(
        itemRelativePath: FilePath,
        srcAttrs: consuming CachedCopySrcItemAttrs? = nil
    ) -> DirCopyResult {
        let srcPath = srcAbsolutePath(of: itemRelativePath)
        let dstPath = dstAbsolutePath(of: itemRelativePath)
        let srcAttrsInternal: CachedCopySrcItemAttrs
        do {
            srcAttrsInternal = srcAttrs == nil ? try cacheItemAttrsForCopy(forItemAt: srcPath) : srcAttrs!
        } catch {
            return .error(error)
        }
        guard srcAttrsInternal.type == .directory else {
            preconditionFailure("srcAttrs must represent a directory")
        }
        do throws(LowLevelError) {
            #if canImport(WinSDK)
            if options.windowsPreserveExactDacl {
                var sd = srcAttrsInternal.securityDescriptor.makeAbsolute()
                sd.addDaclEntries([
                    .init(permission: .genericAll, trustee: .init(sid: try getAndCacheCurrentUser().rawId, type: .unknown))
                ])
                try InternalFS.mkdir(at: dstPath, permissions: sd.view)
            } else {
                try InternalFS.mkdir(at: dstPath, permissions: nil)
            }
            #else
            let permission = [srcAttrsInternal.permission, .ownerReadWriteExecute] as FilePermissions
            try InternalFS.mkdir(at: dstPath, permissions: permission)
            try InternalFS.setPosixPermissions(forItemAt: dstPath, permissions: permission, followSymlink: false)
            #endif
            return .copied(srcAttrsInternal)
        } catch where error.kind == .alreadyExists {
            switch options.existingTarget {
                case .error: return .error(error)
                case .skip: 
                    guard let type = try? InternalFS.type(ofItemAt: dstPath) else {
                        return .error(.unknown)
                    }
                    if type == .directory {
                        return .skipped(srcAccessTime: srcAttrsInternal.accessTime)
                    } else {
                        return .skippedNonDir
                    }
                case .overwrite:
                    guard let type = try? InternalFS.type(ofItemAt: dstPath) else { 
                        return .error(.unknown)
                    }
                    if type == .directory {
                        #if canImport(WinSDK)
                        if options.windowsPreserveExactDacl {
                            do throws(LowLevelError) {
                                var sd = srcAttrsInternal.securityDescriptor.makeAbsolute()
                                sd.addDaclEntries([
                                    .init(permission: .genericAll, trustee: .init(sid: try getAndCacheCurrentUser().rawId, type: .unknown))
                                ])
                                let securityInformation = srcAttrsInternal.securityDescriptor.control.control.contains(.daclProtected) 
                                    ? DWORD(DACL_SECURITY_INFORMATION) | DWORD(PROTECTED_DACL_SECURITY_INFORMATION) 
                                    : DWORD(DACL_SECURITY_INFORMATION)
                                try execThrowingCFunction {
                                    dstPath.withPlatformString { pathPtr in
                                        SetFileSecurityW(pathPtr, securityInformation, sd.psd.unsafeRawPtr)
                                    }
                                }
                            } catch {
                                return .error(error)
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
                            return .error(error)
                        }
                        #endif
                        return .copied(srcAttrsInternal)
                    } else {
                        return .error(.init(kind: .notADirectory))
                    }
            }
        } catch {
            return .error(error)
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
    mutating func copyDirectoryRecursive(
        srcAttrs: consuming CachedCopySrcItemAttrs
    ) throws(RecursiveCopyAbortError) {

        assert(srcAttrs.type == .directory, "srcAttrs must represent a directory")

        var dirStack: RecursiveCopyDirStack

        do throws(LowLevelError) {
            switch copyDir(itemRelativePath: .init(), srcAttrs: srcAttrs) {
                case .copied(let srcAttrs):             // dst not exist or dst is sucessfully overwritten
                    dirStack = .init(rootDirAttrs: .full(srcAttrs))
                case .skipped(let srcAccessTime):       // dst is an existing directory and overwrite is .skip
                    dirStack = .init(rootDirAttrs: .skipped(srcAccessTime: srcAccessTime))
                case .skippedNonDir:                    // dst is an existing non-directory and overwrite is .skip
                    return
                case .error(let error): 
                    throw error
            }
        } catch {
            try errorCollector.handleErrorAndAbort(error, itemRelativePath: .init(root: nil))
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
                do {
                    let dstHandle = try openMetadataHandle(forItemAt: dstAbsolutePath(of: dirRelativePath))
                    #if canImport(Darwin)
                    let srcHandle = try openMetadataHandle(forItemAt: srcAbsolutePath(of: dirRelativePath))
                    try copyDarwinExtendedAttrs(fromHandle: srcHandle, toHandle: dstHandle)
                    #endif
                    try writeCachedItemAttrs(forHandle: dstHandle, members: .all, cachedAttrs: attrs)
                    try dstHandle.close()
                    #if canImport(Darwin)
                    try srcHandle.close()
                    #endif
                } catch {
                    try errorCollector.handleError(error, itemRelativePath: dirRelativePath)
                }
            }
        }

        var enumerator = SkipableDirectoryEntryEnumerator(path: srcAbsolutePath(of: .init()))
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
                case .entryError(let path, let error):
                    try errorCollector.handleError(error, itemRelativePath: path)
                    continue
                case .leavingDir(let path, let error), .subTreeError(let path, let error as LowLevelError?):
                    if let error {
                        try errorCollector.handleError(error, itemRelativePath: path)
                    }
                    try dirStack.removeTopAndPerform(commitDirCopy)
                    continue
                case .entry(let e): 
                    entry = e   
            }

            // technically not necessary since the enumerator will skip '.' and '..' by default, just be defensive
            guard entry.path.lastComponent?.kind == .regular else { continue }

            // the enumerator's element paths are already relative to the source root, which is the copy root here
            let itemRelativePath = entry.path

            do throws(LowLevelError) {
                switch entry.type {
                    case .regular:
                        try copyFile(itemRelativePath: itemRelativePath)
                    case .symlink:
                        try copySymlink(itemRelativePath: itemRelativePath)
                    case .directory:
                        switch copyDir(itemRelativePath: itemRelativePath) {
                            case .copied(let srcAttrs):
                                dirStack.push(name: entry.name, attrs: .full(srcAttrs))
                            case .skipped(let srcAccessTime):
                                dirStack.push(name: entry.name, attrs: .skipped(srcAccessTime: srcAccessTime))
                            case .skippedNonDir:
                                skipCurrentDir = true
                            case .error(let error):
                                skipCurrentDir = true
                                throw error
                        }
                    default:
                        // sockets, fifos, devices, and (on Windows) reparse points that are not symlinks cannot be
                        // copied; report them per item so that the error strategy decides, instead of dropping them
                        // silently. This matches what `copyItem` reports when such an item is the root of the copy.
                        throw .init(kind: .unsupported)
                }
            } catch {
                try errorCollector.handleError(error, itemRelativePath: itemRelativePath)
            }

        }

        try dirStack.removeTopAndPerform(commitDirCopy)

        assert(dirStack.isEmpty, "Internal error: Unexpected non-empty dirAttrsStack after dir traversal")

    }

}