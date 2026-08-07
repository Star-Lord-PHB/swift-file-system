import PlatformCLib
import CFileSystem
import SystemPackage


extension InternalFS {

    #if canImport(WinSDK)
    @available(*, deprecated, message: "Not recomended on Windows for copying files, use copyRegularFileOrSymlink instead")
    #endif 
    package static func copyRegularFileContent(from srcHandle: borrowing UnsafeSystemHandle, to dstHandle: borrowing UnsafeSystemHandle, _ srcFileSize: UInt64? = nil) throws(LowLevelError) {

        #if canImport(WinSDK)

        var buffer = ByteBuffer(count: .init(srcFileSize ?? 0x7ffff000))

        while true {

            let bytesRead = try buffer.withUnsafeMutableBytes { (ptr) throws(LowLevelError) in
                try srcHandle.read(into: ptr)
            }
            guard bytesRead > 0 else { break }

            try buffer.withUnsafeBytes { (ptr) throws(LowLevelError) in
                _ = try dstHandle.write(contentsOf: ptr)
            }

            if bytesRead < buffer.count { break }

        }

        #elseif canImport(Darwin)

        try execThrowingCFunction {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_DATA))
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
                try LowLevelError.assertError()
            }
            guard byteCopied > 0 else { break }

        }

        if fallbackToManualCopy {

            var buffer = ByteBuffer(count: 64 * 1024)

            while true {
                // manual copy, only used when copy_file_range is not available

                let bytesRead = try buffer.withUnsafeMutableBytes { (ptr) throws(LowLevelError) in
                    try srcHandle.read(into: ptr)
                }
                guard bytesRead > 0 else { break }

                try buffer.withUnsafeBytes { (ptr) throws(LowLevelError) in
                    _ = try dstHandle.write(contentsOf: ptr)
                }

                if bytesRead < buffer.count { break }

            }

        }

        #endif 

    }


    #if canImport(Darwin)

    package static func copyItemMetadata(from srcHandle: borrowing UnsafeSystemHandle, to dstHandle: borrowing UnsafeSystemHandle) throws(LowLevelError) {
        try execThrowingCFunction {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_METADATA))
        }
    }


    package static func copyItemContent(from srcPath: FilePath, to dstPath: FilePath, overwrite: Bool = false) throws(LowLevelError) {
        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    copyfile(srcPtr, dstPtr, nil, UInt32(COPYFILE_DATA | COPYFILE_NOFOLLOW | (overwrite ? 0 : COPYFILE_EXCL)))
                }
            }
        }
    }


    package static func copyItemMetadata(from srcPath: FilePath, to dstPath: FilePath, overwrite: Bool = false) throws(LowLevelError) {
        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    copyfile(srcPtr, dstPtr, nil, UInt32(COPYFILE_METADATA | COPYFILE_NOFOLLOW | (overwrite ? 0 : COPYFILE_EXCL)))
                }
            }
        }
    }

    
    package static func copyRegularFileWithMetaNoTimes(
        from srcHandle: borrowing UnsafeSystemHandle, 
        to dstHandle: borrowing UnsafeSystemHandle
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            fcopyfile(srcHandle.unsafeRawHandle, dstHandle.unsafeRawHandle, nil, UInt32(COPYFILE_ALL))
        }
    }


    package static func copyItemWithMetaNoTimes(
        from srcPath: FilePath, 
        to dstPath: FilePath,
        overwrite: Bool
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    copyfile(srcPtr, dstPtr, nil, UInt32(COPYFILE_ALL | COPYFILE_NOFOLLOW | (overwrite ? 0 : COPYFILE_EXCL)))
                }
            }
        }
    }


    package static func copyFileMetaNoTimes(
        from srcPath: FilePath, 
        to dstPath: FilePath
    ) throws(LowLevelError) {
        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    copyfile(srcPtr, dstPtr, nil, UInt32(COPYFILE_METADATA | COPYFILE_NOFOLLOW))
                }
            }
        }
    }
        
    #endif


    #if canImport(WinSDK)

    package static func copyRegularFileOrSymlink(from srcPath: FilePath, to dstPath: FilePath, overwrite: Bool) throws(LowLevelError) {

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
    package static func copyDirectory(from srcPath: FilePath, to dstPath: FilePath, overwrite: Bool) throws(LowLevelError) {

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

}