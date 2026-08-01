@_exported import FileSystemCore

#if canImport(WinSDK)
@_exported import SystemPackage
#else
@_exported import struct SystemPackage.FilePath
@_exported import struct SystemPackage.FilePermissions
#endif
