#if canImport(Darwin)
@_exported import Darwin
#elseif canImport(Glibc)
@_exported import Glibc
#elseif canImport(Musl)
@_exported import Musl
#elseif canImport(WASILibc)
@_exported import WASILibc
#elseif canImport(WinSDK)
@_exported import WinSDK
#elseif canImport(Android)
@_exported import Android
#else
#error("Unsupported Platform")
#endif

internal import CFileSystem



package var SUPPORT_SYMLINK_DESCRIPTOR: Bool {
    _SUPPORT_SYMLINK_DESCRIPTOR == 1
}


#if canImport(Glibc) || canImport(Musl)
package var FS_APPEND_FL: CInt { _FS_APPEND_FL }
package var FS_COMPR_FL: CInt { _FS_COMPR_FL }
package var FS_IMMUTABLE_FL: CInt { _FS_IMMUTABLE_FL }
package var FS_JOURNAL_DATA_FL: CInt { _FS_JOURNAL_DATA_FL }
package var FS_NOATIME_FL: CInt { _FS_NOATIME_FL }
package var FS_NOCOW_FL: CInt { _FS_NOCOW_FL }
package var FS_NODUMP_FL: CInt { _FS_NODUMP_FL }
package var FS_NOTAIL_FL: CInt { _FS_NOTAIL_FL }
package var FS_PROJINHERIT_FL: CInt { _FS_PROJINHERIT_FL }
package var FS_SECRM_FL: CInt { _FS_SECRM_FL }
package var FS_SYNC_FL: CInt { _FS_SYNC_FL }
package var FS_TOPDIR_FL: CInt { _FS_TOPDIR_FL }
package var FS_UNRM_FL: CInt { _FS_UNRM_FL }
package var FS_ENCRYPT_FL: CInt { _FS_ENCRYPT_FL }
package var FS_VERITY_FL: CInt { _FS_VERITY_FL }

@usableFromInline package var STATX_ATTR_COMPRESSED: CInt { _STATX_ATTR_COMPRESSED }
@usableFromInline package var STATX_ATTR_IMMUTABLE: CInt { _STATX_ATTR_IMMUTABLE }
@usableFromInline package var STATX_ATTR_APPEND: CInt { _STATX_ATTR_APPEND }
@usableFromInline package var STATX_ATTR_NODUMP: CInt { _STATX_ATTR_NODUMP }
@usableFromInline package var STATX_ATTR_ENCRYPTED: CInt { _STATX_ATTR_ENCRYPTED }
@usableFromInline package var STATX_ATTR_AUTOMOUNT: CInt { _STATX_ATTR_AUTOMOUNT }
@usableFromInline package var STATX_ATTR_MOUNT_ROOT: CInt { _STATX_ATTR_MOUNT_ROOT }
@usableFromInline package var STATX_ATTR_VERITY: CInt { _STATX_ATTR_VERITY }
@usableFromInline package var STATX_ATTR_WRITE_ATOMIC: CInt { _STATX_ATTR_WRITE_ATOMIC }
@usableFromInline package var STATX_ATTR_DAX: CInt { _STATX_ATTR_DAX }


package var UTIME_OMIT: Int32 {
    Int32(_UTIME_OMIT)
}
package func renameat2(_ olddirfd: CInt, _ oldpath: UnsafePointer<CChar>, _ newdirfd: CInt, _ newpath: UnsafePointer<CChar>, _ flags: UInt32) -> CInt {
    return _renameat2(olddirfd, oldpath, newdirfd, newpath, flags)
}
package var RENAME_NOREPLACE: Int32 {
    Int32(_RENAME_NOREPLACE)
}
#endif 