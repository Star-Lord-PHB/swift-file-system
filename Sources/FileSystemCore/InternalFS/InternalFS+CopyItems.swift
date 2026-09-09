import PlatformCLib
import CFileSystem
import SystemPackage


extension InternalFS {

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

    package static func copyRegularFileOrSymlink(
        from srcPath: FilePath, 
        to dstPath: FilePath, 
        overwrite: Bool, 
        callbackArg: UnsafeUnownedMutableRawPointer?,
        callback: LPPROGRESS_ROUTINE?
    ) throws(LowLevelError) {

        let flags = DWORD(COPY_FILE_COPY_SYMLINK) | (overwrite ? 0 : DWORD(COPY_FILE_FAIL_IF_EXISTS))

        try execThrowingCFunction {
            srcPath.withPlatformString { srcPtr in 
                dstPath.withPlatformString { dstPtr in 
                    CopyFileExW(srcPtr, dstPtr, callback, callbackArg?.unsafeRawPtr, nil, flags)
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
