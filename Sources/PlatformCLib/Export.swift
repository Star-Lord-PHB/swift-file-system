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