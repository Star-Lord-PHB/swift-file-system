import PlatformCLib
import CFileSystem
import SystemPackage


@usableFromInline
enum InternalFS {

    static func rename(itemAt srcPath: FilePath, to dstPath: FilePath, replace: Bool = true) throws(SystemError) {

        #if canImport(WinSDK)

        // Due to the different behaviour of MoveFileExW on Windows and rename on POSIX, 
        // The Windows implementation is relatively more complex and unsafe to TOCTOU issues.

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

        if try type(ofItemAt: srcPath) != .directory {
            try execThrowingCFunction {
                srcPath.withPlatformString { srcPtr in 
                    dstPath.withPlatformString { dstPtr in 
                        MoveFileExW(srcPtr, dstPtr, DWORD(MOVEFILE_REPLACE_EXISTING))
                    }
                }
            }
            return
        }

        // Here, the source item must be a directory, we check the type of the destination item
        // If it's a directory, we can remove it first then do the move, since MoveFileExW does not support replacing existing empty directory
        // If destination not exists, go to next step
        // If destination exists and is not a directory, throw an error
        // If other errors occurs, throw the error

        do throws(SystemError) {
            guard try type(ofItemAt: dstPath) == .directory else {
                throw SystemError(code: .notADirectory)!
            }
            try rmdir(at: dstPath)
        } catch let error where error.kind == .notFound {
            // Only ignore error where the destination not exists, other errors are all rethrown
        }

        // finally do the move again

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    MoveFileExW(srcPtr, dstPtr, DWORD(MOVEFILE_REPLACE_EXISTING))
                }
            }
        }

        #elseif canImport(Darwin)

        let flags = replace ? UInt32(0) : UInt32(RENAME_EXCL)

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    renamex_np(srcPtr, dstPtr, flags)
                }
            }
        }

        #elseif os(FreeBSD) || os(OpenBSD)

        // use manual check and rename to simulate no-replace behaviour

        if replace {
            switch (itemExists(at: dstPath), targetExistOption) {
                case (true, .skip): return 
                case (true, .error): throw SystemError(code: .fileExists)!
                case (_, _): break
            }
        }

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    rename(srcPtr, dstPtr)
                }
            }
        }

        #else

        let flags = replace ? UInt32(0) : UInt32(RENAME_NOREPLACE)

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    renameat2(AT_FDCWD, srcPtr, AT_FDCWD, dstPtr, flags)
                }
            }
        }

        #endif 

    }


    #if canImport(WinSDK)
    @available(*, deprecated, message: "Not recomended on Windows for copying files, use copyRegularFileOrSymlink instead")
    #endif 
    static func copyRegularFile(from srcHandle: borrowing UnsafeSystemHandle, to dstHandle: borrowing UnsafeSystemHandle, _ srcFileSize: UInt64? = nil) throws(SystemError) {

        #if canImport(WinSDK)

        var buffer = ByteBuffer(count: .init(srcFileSize ?? 0x7ffff000))

        while true {

            let bytesRead = try buffer.withUnsafeMutableBytes { (ptr) throws(SystemError) in
                try srcHandle.read(into: ptr)
            }
            guard bytesRead > 0 else { break }

            try buffer.withUnsafeBytes { (ptr) throws(SystemError) in
                _ = try dstHandle.write(contentsOf: ptr)
            }

            if bytesRead < buffer.count { break }

        }

        #elseif canImport(Darwin)

        try execThrowingCFunction {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_ALL))
        }

        #else 

        var srcOffset: off_t = 0
        var dstOffset: off_t = 0
        var fallbackToManualCopy = false

        while true {
            // faster path using copy_file_range if available

            let byteCopied = copy_file_range(srcHandle.unsafeRawHandle, &srcOffset, dstHandle.unsafeRawHandle, &dstOffset, .init(srcFileSize ?? 0x7ffff000), 0)
            if byteCopied < 0 && errno == ENOSYS {
                // copy_file_range not available, fallback to manual copy
                fallbackToManualCopy = true
                break
            }
            // EINTR (interrupted) can be ignored and simply retry
            guard byteCopied >= 0 || errno != EINTR else {
                try SystemError.assertError()
            }
            guard byteCopied > 0 else { break }

        }

        if fallbackToManualCopy {

            var buffer = ByteBuffer(count: 64 * 1024)

            while true {
                // manual copy, only used when copy_file_range is not available

                let bytesRead = try buffer.withUnsafeMutableBytes { (ptr) throws(SystemError) in
                    try srcHandle.read(into: ptr)
                }
                guard bytesRead > 0 else { break }

                try buffer.withUnsafeBytes { (ptr) throws(SystemError) in
                    _ = try dstHandle.write(contentsOf: ptr)
                }

                if bytesRead < buffer.count { break }

            }

        }

        #endif 

    }


    #if canImport(WinSDK)

    static func copyRegularFileOrSymlink(from srcPath: FilePath, to dstPath: FilePath, overwrite: Bool) throws(SystemError) {

        let flags = DWORD(COPY_FILE_COPY_SYMLINK) | (overwrite ? 0 : DWORD(COPY_FILE_FAIL_IF_EXISTS))

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    CopyFileExW(srcPtr, dstPtr, nil, nil, nil, flags)
                }
            }
        }

    }


    /// > Warning: 
    /// > May fail on older Windows system, check ERROR_INVALID_PARAMETER and ERROR_NOT_SUPPORTED for that
    /// > and fallback to manual copy if needed
    static func copyDirectory(from srcPath: FilePath, to dstPath: FilePath, overwrite: Bool) throws(SystemError) {

        let flags = DWORD(COPY_FILE_DIRECTORY) | (overwrite ? 0 : DWORD(COPY_FILE_FAIL_IF_EXISTS))

        var param = COPYFILE2_EXTENDED_PARAMETERS()
        param.dwSize = DWORD(MemoryLayout<COPYFILE2_EXTENDED_PARAMETERS>.size)
        param.dwCopyFlags = flags

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    CopyFile2(srcPtr, dstPtr, &param)
                }
            }
        }

    }

    #endif 


    static func makeRandomTmpName(in dirPath: FilePath, prefix: FilePath.Component) -> FilePath {

        #if canImport(WinSDK)
        let pid = GetCurrentProcessId()
        #else 
        let pid = getpid()
        #endif
        let lastComponent = FilePath.Component("\(prefix).tmp-\(pid)-\(String(UInt64.random(in: 0 ... .max), radix: 16))")!
        return dirPath.appending(lastComponent)

    }


    static func makeRandomTmpName(baseOn path: FilePath) -> FilePath {
        assert(path.lastComponent != nil, "base path for temp file name must not be empty")
        return makeRandomTmpName(in: path.removingLastComponent(), prefix: path.lastComponent!)
    }


    struct TmpFileResult: ~Copyable {
        let path: FilePath
        let handle: UnsafeSystemHandle
        consuming func takeHandle() -> UnsafeSystemHandle {
            return handle
        }
    }


    static func makeTmpFile(in dirPath: FilePath, prefix: FilePath.Component) throws(SystemError) -> TmpFileResult {

        #if canImport(WinSDK)

        for _ in 0 ..< 24 {
            
            let tmpPath = makeRandomTmpName(in: dirPath, prefix: prefix)

            do {
                let handle = try UnsafeSystemHandle.open(
                    at: tmpPath, 
                    openOptions: .init(access: .readWrite(), creation: .assertMissing)
                )
                return .init(path: tmpPath, handle: handle)
            } catch let error where error.kind == .alreadyExists {
                // try again
                continue
            }

        }

        throw SystemError(code: .fileExists)!

        #else

        var pathBuffer = (dirPath.string + "/\(prefix).tmp-XXXXXX").utf8CString

        let fd = pathBuffer.withUnsafeMutableBufferPointer { strPtr in 
            mkstemp(strPtr.baseAddress!)
        }

        guard fd >= 0 else {
            try SystemError.assertError()
        }

        let tmpPath = pathBuffer.withUnsafeBufferPointer { FilePath(platformString: $0.baseAddress!) }

        return .init(path: tmpPath, handle: .init(owningRawHandle: fd))

        #endif 

    }


    static func makeTmpFile(baseOn path: FilePath) throws(SystemError) -> TmpFileResult {

        assert(path.lastComponent != nil, "base path for temp file must not be empty")
        return try makeTmpFile(in: path.removingLastComponent(), prefix: path.lastComponent!)

    }


    static func readlink(fromSymlinkAt linkPath: FilePath) throws(SystemError) -> FilePath {

        #if canImport(WinSDK)

        let handle = try UnsafeSystemHandle.open(
            at: linkPath, 
            openOptions: .init(access: .readOnly(), noFollow: true, platformSpecificOptions: .windows.backupSemantics)
        )

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(MAXIMUM_REPARSE_DATA_BUFFER_SIZE), 
            alignment: MemoryLayout<UInt8>.alignment
        ).assumingMemoryBound(to: MAPPED_REPARSE_DATA_BUFFER.self)

        defer { buffer.deallocate() }

        var bytesReturned = 0 as DWORD

        try execThrowingCFunction {
            DeviceIoControl(
                handle.unsafeRawHandle, 
                DWORD(FSCTL_GET_REPARSE_POINT), 
                nil, 0, 
                buffer, DWORD(MAXIMUM_REPARSE_DATA_BUFFER_SIZE), &bytesReturned, nil
            )
        }

        guard buffer.pointee.ReparseTag == IO_REPARSE_TAG_SYMLINK else {
            throw SystemError(code: .platform(.badArguments))!
        }

        if buffer.pointee.SymbolicLinkReparseBuffer.PrintNameLength > 0 {
            let namePtr = getReparseDataBufferSymbolicLinkPathBuffer(buffer) + Int(buffer.pointee.SymbolicLinkReparseBuffer.PrintNameOffset) / MemoryLayout<WCHAR>.size
            let charCount = (Int(buffer.pointee.SymbolicLinkReparseBuffer.PrintNameLength) / MemoryLayout<WCHAR>.size)
            let nameBuffer = [WCHAR](unsafeUninitializedCapacity: charCount + 1) { buffer, initializedCount in 
                initializedCount = buffer.moveInitialize(fromContentsOf: UnsafeMutableBufferPointer<WCHAR>(start: namePtr, count: charCount))
                buffer[charCount] = 0   // the null terminator
                initializedCount += 1
            }
            return .init(platformString: nameBuffer)
        } else {
            let namePtr = getReparseDataBufferSymbolicLinkPathBuffer(buffer) + Int(buffer.pointee.SymbolicLinkReparseBuffer.SubstituteNameOffset) / MemoryLayout<WCHAR>.size
            let charCount = (Int(buffer.pointee.SymbolicLinkReparseBuffer.SubstituteNameLength) / MemoryLayout<WCHAR>.size)
            let nameBuffer = [WCHAR](unsafeUninitializedCapacity: charCount + 1) { buffer, initializedCount in 
                initializedCount = buffer.moveInitialize(fromContentsOf: UnsafeMutableBufferPointer<WCHAR>(start: namePtr, count: charCount))
                buffer[charCount] = 0   // the null terminator
                initializedCount += 1
            }
            return .init(platformString: nameBuffer)
        }

        #else

        var buffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: Int(max(PATH_MAX, 1024)))
        defer { buffer.deallocate() }

        while true {
            let len = linkPath.withPlatformString { strPtr in 
                PlatformCLib.readlink(strPtr, buffer.baseAddress!, buffer.count - 1)
            }
            if len < 0 {
                try SystemError.assertError()
            } else if len == buffer.count - 1 {
                let newBuffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: buffer.count * 2)
                _ = newBuffer.moveInitialize(fromContentsOf: buffer)
                buffer.deallocate()
                buffer = newBuffer
            } else {
                buffer[len] = 0
                break
            }
        }

        return .init(platformString: buffer.baseAddress!)

        #endif

    }


    static func realpath(of path: FilePath) throws(SystemError) -> FilePath {

        #if canImport(WinSDK)
        
        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: false, platformSpecificOptions: .windows.backupSemantics)
        )

        var buffer = UnsafeMutableBufferPointer<WCHAR>.allocate(capacity: Int(MAX_PATH + 1))
        defer { buffer.deallocate() }

        while true {
            let size = GetFinalPathNameByHandleW(handle.unsafeRawHandle, buffer.baseAddress!, DWORD(buffer.count), 0)
            if size > buffer.count {
                let newBuffer = UnsafeMutableBufferPointer<WCHAR>.allocate(capacity: Int(size))
                _ = newBuffer.moveInitialize(fromContentsOf: buffer)
                buffer.deallocate()
                buffer = newBuffer
            } else if size == 0 {
                try SystemError.assertError()
            } else {
                break
            }
        }

        return .init(platformString: buffer.baseAddress!)

        #else

        let buffer = path.withPlatformString { strPtr in 
            PlatformCLib.realpath(strPtr, nil)
        }
        guard let buffer else {
            try SystemError.assertError()
        }

        defer { free(buffer) }

        return .init(platformString: buffer)

        #endif 

    }


    static func unlink(fileAt path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                DeleteFileW(pathPtr)
            }
        }

        #else 

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                PlatformCLib.unlink(pathPtr)
            }
        }

        #endif

    }


    static func rmdir(at path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                RemoveDirectoryW(pathPtr)
            }
        }

        #else 

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                PlatformCLib.rmdir(pathPtr)
            }
        }

        #endif

    }


    static func remove(itemAt path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        do {
            try unlink(fileAt: path)
        } catch let error where error.kind == .permissionDenied {
            try rmdir(at: path)
        }

        #else 

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                PlatformCLib.remove(pathPtr)
            }
        }

        #endif

    }


    static func mkdir(at path: FilePath, permissions: FilePermissions?) throws(SystemError) {

        #if canImport(WinSDK)

        let psd = try permissions.map { (p) throws(SystemError) in 
            try WindowsAPI.securityDescriptor(fromPosixPermissions: p, forDir: true)
        }

        var sa = SECURITY_ATTRIBUTES()
        sa.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size)
        switch psd {
            case .some(let psd):    sa.lpSecurityDescriptor = LPVOID(psd.unsafeRawPtr)
            case .none:             sa.lpSecurityDescriptor = nil
        }

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                CreateDirectoryW(pathPtr, &sa)
            }
        }

        #else 

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                PlatformCLib.mkdir(pathPtr, (permissions ?? [.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute]).rawValue)
            }
        }

        #endif

    }


    #if canImport(WinSDK)
    static func mkdir(at path: FilePath, permission: borrowing WindowsSelfRelativeSecurityDescriptor?) throws(SystemError) {
        
        var sa = SECURITY_ATTRIBUTES()
        sa.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size)
        switch permission {
            case .some(let permission):    sa.lpSecurityDescriptor = LPVOID(permission.psd.unsafeRawPtr)
            case .none:                    sa.lpSecurityDescriptor = nil
        }

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                CreateDirectoryW(pathPtr, &sa)
            }
        }
        
    }
    #endif 


    static func symlink(dstPath: FilePath, linkPath: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        let attr = dstPath.withPlatformString { dstPathPtr in 
            GetFileAttributesW(dstPathPtr)
        }

        let isDir: Bool

        if attr == INVALID_FILE_ATTRIBUTES {
            do {
                try SystemError.assertError()
            } catch let error where error.kind == .notFound {
                // destination not exists, ignore the error and assume it's a file
                isDir = false
            }
        } else {
            isDir = (attr & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0
        }

        let flags = DWORD(SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE) | DWORD(isDir ? SYMBOLIC_LINK_FLAG_DIRECTORY : 0)

        try execThrowingCFunction {
            linkPath.withPlatformString { linkPtr in 
                dstPath.withPlatformString { dstPtr in 
                    CreateSymbolicLinkW(linkPtr, dstPtr, flags) == 1
                }
            }
        }

        #else 

        try execThrowingCFunction {
            linkPath.withPlatformString { linkPtr in 
                dstPath.withPlatformString { dstPtr in 
                    PlatformCLib.symlink(dstPtr, linkPtr)
                }
            }
        }

        #endif

    }


    static func link(existingPath: FilePath, newPath: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        try execThrowingCFunction {
            existingPath.withPlatformString { existingPtr in 
                newPath.withPlatformString { newPtr in 
                    CreateHardLinkW(newPtr, existingPtr, nil)
                }
            }
        }

        #else 

        try execThrowingCFunction {
            existingPath.withPlatformString { existingPtr in 
                newPath.withPlatformString { newPtr in 
                    PlatformCLib.linkat(AT_FDCWD, existingPtr, AT_FDCWD, newPtr, 0)
                }
            }
        }

        #endif

    }


    #if canImport(WinSDK)
    
    static func utimes(for path: FilePath, creation: FILETIME?, access: FILETIME?, modify: FILETIME?) throws(SystemError) {
        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .writeOnly(metadataOnly: true), noFollow: true, platformSpecificOptions: .windows.backupSemantics)
        )
        try futimes(for: handle, creation: creation, access: access, modify: modify)
        try handle.close()
    }

    static func futimes(for handle: borrowing UnsafeSystemHandle, creation: FILETIME?, access: FILETIME?, modify: FILETIME?) throws(SystemError) {
        try execThrowingCFunction {
            withUnsafeOptionalPointer(to: creation) { creationPtr in 
                withUnsafeOptionalPointer(to: access) { accessPtr in 
                    withUnsafeOptionalPointer(to: modify) { modifyPtr in 
                        PlatformCLib.SetFileTime(
                            handle.unsafeRawHandle, 
                            creationPtr, 
                            accessPtr, 
                            modifyPtr
                        )
                    }
                }
            }
        }
    }

    #else 

    static func utimens(for path: FilePath, times: (timespec, timespec)) throws(SystemError) {
        try execThrowingCFunction {
            withUnsafePointer(to: times) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    path.withPlatformString { pathPtr in 
                        utimensat(AT_FDCWD, pathPtr, reboundPtr, AT_SYMLINK_NOFOLLOW)
                    }
                }
            }
        }
    }


    static func futimens(for handle: borrowing UnsafeSystemHandle, times: (timespec, timespec)) throws(SystemError) {
        try execThrowingCFunction {
            withUnsafePointer(to: times) { ptr in 
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in 
                    PlatformCLib.futimens(handle.unsafeRawHandle, reboundPtr)
                }
            }
        }
    }

    #endif

}