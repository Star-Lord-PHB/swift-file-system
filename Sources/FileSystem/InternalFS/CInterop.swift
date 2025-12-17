import SystemPackage
import PlatformCLib



extension CInterop {

    #if canImport(WinSDK)
    public typealias PlatformFileTime = FILETIME
    #else
    public typealias PlatformFileTime = timespec
    #endif


    #if canImport(Glibc) || canImport(Musl)
    public typealias PlatformFileAttribute = UInt64
    #elseif canImport(WinSDK)
    public typealias PlatformFileAttribute = DWORD
    #else 
    public typealias PlatformFileAttribute = UInt32
    #endif


    #if !canImport(WinSDK)
    public typealias PosixInodeFlags = CInt
    #endif

}