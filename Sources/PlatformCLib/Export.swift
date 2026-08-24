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

@_exported import CFileSystem


#if canImport(Glibc) || canImport(Musl)

package var UTIME_OMIT: Int32 {
    Int32(_UTIME_OMIT)
}
package var UTIME_NOW: Int32 {
    Int32(_UTIME_NOW)
}
package func renameat2(_ olddirfd: CInt, _ oldpath: UnsafePointer<CChar>, _ newdirfd: CInt, _ newpath: UnsafePointer<CChar>, _ flags: UInt32) -> CInt {
    return _renameat2(olddirfd, oldpath, newdirfd, newpath, flags)
}
#endif


#if canImport(Glibc) || canImport(Musl) || canImport(Android)
package func pthread_setname_current(_ name: UnsafePointer<CChar>) -> CInt {
    return _pthread_setname_current(name)
}
#endif



#if canImport(WinSDK)
@usableFromInline package var FILE_GENERIC_READ: ACCESS_MASK { _FILE_GENERIC_READ }
@usableFromInline package var FILE_GENERIC_WRITE: ACCESS_MASK { _FILE_GENERIC_WRITE }
@usableFromInline package var FILE_GENERIC_EXECUTE: ACCESS_MASK { _FILE_GENERIC_EXECUTE }
@usableFromInline package var FILE_ALL_ACCESS: ACCESS_MASK { _FILE_ALL_ACCESS }
#endif