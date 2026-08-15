import PlatformCLib
import CFileSystem
import SystemPackage


extension InternalFS {

    package static func rename(
        itemAt srcPath: FilePath,
        to dstPath: FilePath,
        replace: Bool = true
    ) throws(LowLevelError) {

        #if canImport(WinSDK)
        try windowsRename(itemAt: srcPath, to: dstPath, replace: replace)
        #elseif canImport(Darwin)
        try darwinRename(itemAt: srcPath, to: dstPath, replace: replace)
        #elseif os(FreeBSD) || os(OpenBSD)
        try bsdRename(itemAt: srcPath, to: dstPath, replace: replace)
        #else
        try linuxRename(itemAt: srcPath, to: dstPath, replace: replace)
        #endif

    }

}



#if canImport(WinSDK)

extension InternalFS {

    private static func windowsRename(
        itemAt srcPath: FilePath,
        to dstPath: FilePath,
        replace: Bool
    ) throws(LowLevelError) {

        let srcHandle = srcPath.withPlatformString { srcPtr in
            CreateFileW(
                srcPtr,
                DWORD(DELETE),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS),
                nil
            )
        }
        guard let srcHandle, srcHandle != INVALID_HANDLE_VALUE else {
            try LowLevelError.assertError()
        }
        defer { CloseHandle(srcHandle) }

        if windowsVolumeSupportsPosixUnlinkRename(srcHandle) {
            try windowsPosixSemanticsRename(srcHandle: srcHandle, to: dstPath, replace: replace)
        } else {
            try windowsMoveFileChainRename(itemAt: srcPath, srcHandle: srcHandle, to: dstPath, replace: replace)
        }

    }


    /// Whether the volume backing the handle declares `FILE_SUPPORTS_POSIX_UNLINK_RENAME`,
    /// i.e. it accepts the `FileRenameInfoEx` / `FileDispositionInfoEx` info classes. The
    /// bit shipped together with those info classes, so it covers both an old kernel and
    /// an unsupporting filesystem.
    private static func windowsVolumeSupportsPosixUnlinkRename(_ handle: HANDLE) -> Bool {
        var fileSystemFlags = 0 as DWORD
        let success = GetVolumeInformationByHandleW(handle, nil, 0, nil, nil, &fileSystemFlags, nil, 0)
        guard success else { return false }
        return fileSystemFlags & DWORD(FILE_SUPPORTS_POSIX_UNLINK_RENAME) != 0
    }


    /// The fast path: the `FileRenameInfoEx` info class with POSIX semantics. The kernel
    /// performs the existence check and the replacement as one atomic operation —
    /// including replacing an empty directory with a directory — so none of the
    /// check-and-act windows of the `MoveFileExW` chain exist here. A failure on this
    /// path is a real error and is never retried through that chain.
    private static func windowsPosixSemanticsRename(
        srcHandle: HANDLE,
        to dstPath: FilePath,
        replace: Bool
    ) throws(LowLevelError) {

        // The NT layer does not resolve working-directory-relative names.
        let absoluteDstPath = try windowsFullPath(of: dstPath)

        let nameBytes = absoluteDstPath.withPlatformString { Int(wcslen($0)) } * MemoryLayout<WCHAR>.size
        // FILE_RENAME_INFO already reserves one WCHAR, which holds the terminator.
        let infoSize = MemoryLayout<FILE_RENAME_INFO>.size + nameBytes

        let infoBuffer = UnsafeMutableRawPointer.allocate(
            byteCount: infoSize,
            alignment: MemoryLayout<FILE_RENAME_INFO>.alignment
        )
        defer { infoBuffer.deallocate() }
        infoBuffer.initializeMemory(as: UInt8.self, repeating: 0, count: infoSize)

        let info = infoBuffer.assumingMemoryBound(to: FILE_RENAME_INFO.self)
        info.pointee.Flags = DWORD(FILE_RENAME_FLAG_POSIX_SEMANTICS)
            | (replace ? DWORD(FILE_RENAME_FLAG_REPLACE_IF_EXISTS) : 0)
        info.pointee.RootDirectory = nil
        info.pointee.FileNameLength = DWORD(nameBytes)

        let nameOffset = MemoryLayout<FILE_RENAME_INFO>.offset(of: \.FileName)!
        absoluteDstPath.withPlatformString { dstPtr in
            (infoBuffer + nameOffset).copyMemory(from: dstPtr, byteCount: nameBytes)
        }

        try execThrowingCFunction {
            SetFileInformationByHandle(srcHandle, FileRenameInfoEx, infoBuffer, DWORD(infoSize))
        } onError: { () throws(LowLevelError) in
            let error = LowLevelError.fromLastError()
            switch error?.systemCode {
                // On the replace path the kernel reports a directory destination with
                // the same code as a genuine permission problem.
                case .accessDenied where replace:
                    throw error!.overridingKind(.windows.permissionDeniedOrIsADirectory)
                default:
                    throw error ?? .unknown
            }
        }

    }


    /// The Win32 fallback for volumes without POSIX rename support. Due to the different
    /// behaviour of `MoveFileExW` on Windows and rename on POSIX, this chain is
    /// relatively more complex and unsafe to TOCTOU issues.
    private static func windowsMoveFileChainRename(
        itemAt srcPath: FilePath,
        srcHandle: HANDLE,
        to dstPath: FilePath,
        replace: Bool
    ) throws(LowLevelError) {

        // first try to simply do the move without replacing, if fails with already exists error and replace is true, go to next step

        do {
            try execThrowingCFunction {
                srcPath.withPlatformString { srcPtr in
                    dstPath.withPlatformString { dstPtr in
                        MoveFileW(srcPtr, dstPtr)
                    }
                }
            }
            return
        } catch let error where replace && error.kind == .alreadyExists { /* ignore */ }

        // if source item is not a directory, do replace again with MOVEFILE_REPLACE_EXISTING flag

        if try windowsKind(ofHandle: srcHandle) != .directory {
            do throws(LowLevelError) {
                try windowsMoveFileExReplace(itemAt: srcPath, to: dstPath)
            } catch let error where error.systemCode == .accessDenied {
                // A directory-attributed link entry (directory symlink or junction) is replaced
                // by deleting the entry and retrying — MOVEFILE_REPLACE_EXISTING refuses anything
                // carrying the DIRECTORY attribute. A real directory keeps the ambiguous kind.
                guard windowsIsDirectoryLinkEntry(at: dstPath) else {
                    throw error.overridingKind(.windows.permissionDeniedOrIsADirectory)
                }
                try rmdir(at: dstPath)
                do throws(LowLevelError) {
                    try windowsMoveFileExReplace(itemAt: srcPath, to: dstPath)
                } catch let retryError where retryError.systemCode == .accessDenied {
                    throw retryError.overridingKind(.windows.permissionDeniedOrIsADirectory)
                }
            }
            return
        }

        // Here, the source item must be a directory, we check the type of the destination item
        // If it's a directory, we can remove it first then do the move, since MoveFileExW does not support replacing existing empty directory
        // If destination not exists, go to next step
        // If destination exists and is not a directory, throw an error
        // If other errors occurs, throw the error

        do throws(LowLevelError) {
            guard try type(ofItemAt: dstPath) == .directory else {
                throw .init(kind: .notADirectory)
            }
            try rmdir(at: dstPath)
        } catch let error where error.kind == .notFound {
            // Only ignore error where the destination not exists, other errors are all rethrown
        }

        // finally do the move again

        try windowsMoveFileExReplace(itemAt: srcPath, to: dstPath)

    }


    /// The source's kind read through the already-open handle, so the chain never
    /// resolves the source path a second time.
    private static func windowsKind(ofHandle handle: HANDLE) throws(LowLevelError) -> FileKind {
        var tagInfo = FILE_ATTRIBUTE_TAG_INFO()
        try execThrowingCFunction {
            GetFileInformationByHandleEx(
                handle,
                FileAttributeTagInfo,
                &tagInfo,
                DWORD(MemoryLayout<FILE_ATTRIBUTE_TAG_INFO>.size)
            )
        }
        return FileKind(windowsFileAttributes: tagInfo.FileAttributes, reparseTag: tagInfo.ReparseTag)
    }


    private static func windowsMoveFileExReplace(
        itemAt srcPath: FilePath,
        to dstPath: FilePath
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in
                dstPath.withPlatformString { dstPtr in
                    MoveFileExW(srcPtr, dstPtr, DWORD(MOVEFILE_REPLACE_EXISTING))
                }
            }
        }
    }


    /// Whether the destination names a directory-attributed link entry — a directory
    /// symlink or a junction. Non-surrogate reparse points (e.g. cloud placeholder
    /// directories) classify as real directories and are excluded.
    private static func windowsIsDirectoryLinkEntry(at path: FilePath) -> Bool {
        guard let attributes = try? getFileAttributes(forItemAt: path, followSymlink: false) else {
            return false
        }
        guard
            attributes.contains(.windows.isDirectory),
            attributes.contains(.windows.isReparsePoint)
        else {
            return false
        }
        guard let kind = try? type(ofItemAt: path) else { return false }
        return kind == .symlink || kind == .unknown
    }


    private static func windowsFullPath(of path: FilePath) throws(LowLevelError) -> FilePath {

        let fullPath: FilePath? = path.withPlatformString { pathPtr in
            let requiredLength = GetFullPathNameW(pathPtr, 0, nil, nil)
            guard requiredLength > 0 else { return nil }
            return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(requiredLength)) { buffer in
                let writtenLength = GetFullPathNameW(pathPtr, requiredLength, buffer.baseAddress, nil)
                guard writtenLength > 0, writtenLength < requiredLength else { return nil as FilePath? }
                return FilePath(platformString: buffer.baseAddress!)
            }
        }

        guard let fullPath else { try LowLevelError.assertError() }
        return fullPath

    }

}

#else

extension InternalFS {

    #if canImport(Darwin)

    private static func darwinRename(
        itemAt srcPath: FilePath,
        to dstPath: FilePath,
        replace: Bool
    ) throws(LowLevelError) {

        let flags = replace ? UInt32(0) : UInt32(RENAME_EXCL)

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in
                dstPath.withPlatformString { dstPtr in
                    renamex_np(srcPtr, dstPtr, flags)
                }
            }
        }

    }

    #elseif os(FreeBSD) || os(OpenBSD)

    private static func bsdRename(
        itemAt srcPath: FilePath,
        to dstPath: FilePath,
        replace: Bool
    ) throws(LowLevelError) {

        // use manual check and rename to simulate no-replace behaviour

        var itemExists: Bool {
            var stat = stat()
            return dstPath.withPlatformString { pathPtr in
                lstat(pathPtr, &stat) == 0
            }
        }

        if !replace && itemExists {
            throw .init(kind: .alreadyExists)
        }

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in
                dstPath.withPlatformString { dstPtr in
                    rename(srcPtr, dstPtr)
                }
            }
        }

    }

    #else

    private static func linuxRename(
        itemAt srcPath: FilePath,
        to dstPath: FilePath,
        replace: Bool
    ) throws(LowLevelError) {

        let flags = replace ? UInt32(0) : UInt32(RENAME_NOREPLACE)

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in
                dstPath.withPlatformString { dstPtr in
                    renameat2(AT_FDCWD, srcPtr, AT_FDCWD, dstPtr, flags)
                }
            }
        }

    }

    #endif

}

#endif
