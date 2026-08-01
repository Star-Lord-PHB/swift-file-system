import PlatformCLib
import CFileSystem
import SystemPackage


@usableFromInline
package enum InternalFS {

    package static func rename(itemAt srcPath: FilePath, to dstPath: FilePath, replace: Bool = true) throws(LowLevelError) {

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
            } onError: { () throws(LowLevelError) in
                let error = LowLevelError.fromLastError()
                switch error?.systemCode {
                    case .accessDenied: throw error!.overridingKind(.windows.permissionDeniedOrIsADirectory)
                    default: throw error ?? .unknown
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


    package static func readlink(fromSymlinkAt linkPath: FilePath) throws(LowLevelError) -> FilePath {

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
            throw .init(kind: .notASymlink)
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
                do {
                    try LowLevelError.assertError()
                } catch let error where error.systemCode == .invalidArgument {
                    throw error.overridingKind(.notASymlink)
                }
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


    package static func realpath(of path: FilePath) throws(LowLevelError) -> FilePath {

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
                try LowLevelError.assertError()
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
            try LowLevelError.assertError()
        }

        defer { free(buffer) }

        return .init(platformString: buffer)

        #endif 

    }


    package static func unlink(fileAt path: FilePath) throws(LowLevelError) {

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


    package static func rmdir(at path: FilePath) throws(LowLevelError) {

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


    package static func remove(itemAt path: FilePath) throws(LowLevelError) {

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


    package static func mkdir(at path: FilePath, permissions: FilePermissions?) throws(LowLevelError) {

        #if canImport(WinSDK)

        var sa = SECURITY_ATTRIBUTES()
        sa.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size)
        if let permissions {
            let sd = try WindowsAbsoluteSecurityDescriptor.makeForCurrentUser(fromPosixPermissions: permissions, forDir: true)
            sa.lpSecurityDescriptor = LPVOID(sd.psd.unsafeRawPtr)

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
    package static func mkdir(at path: FilePath, permissions: WindowsSecurityDescriptorView) throws(LowLevelError) {
        var sa = SECURITY_ATTRIBUTES()
        sa.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size)
        sa.lpSecurityDescriptor = LPVOID(permissions.psd.unsafelyCastedMutableRawPtr)
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                CreateDirectoryW(pathPtr, &sa)
            }
        }
    }
    #endif


    package static func symlink(dstPath: FilePath, linkPath: FilePath) throws(LowLevelError) {

        #if canImport(WinSDK)

        let pathToInspect = dstPath.isRelative
            ? linkPath.removingLastComponent().appending(dstPath.components)
            : dstPath
        let attr = pathToInspect.withPlatformString { dstPathPtr in
            GetFileAttributesW(dstPathPtr)
        }

        let isDir: Bool

        if attr == INVALID_FILE_ATTRIBUTES {
            do {
                try LowLevelError.assertError()
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


    package static func link(existingPath: FilePath, newPath: FilePath) throws(LowLevelError) {

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
    
    
    #if !canImport(WinSDK)
    package static func makeFifo(
        at path: FilePath,
        permissions: FilePermissions = [.ownerReadWrite, .groupRead, .otherRead]
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                mkfifo(pathPtr, permissions.rawValue)
            }
        }
    }
    #endif

}
