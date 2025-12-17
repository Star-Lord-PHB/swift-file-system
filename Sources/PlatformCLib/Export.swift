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
package var UTIME_OMIT: Int32 {
    Int32(_UTIME_OMIT)
}
#endif 