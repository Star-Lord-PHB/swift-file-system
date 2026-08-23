/// Centralized compile-time platform capabilities used by filesystem tests.
extension FileSystemTestSupport {

    enum PlatformCapabilities {

        #if canImport(WinSDK)
            static let supportsPosixPermissions = false
            static let supportsWindowsSecurity = true
        #else
            static let supportsPosixPermissions = true
            static let supportsWindowsSecurity = false
        #endif

        #if canImport(Glibc) || canImport(Musl)
            static let supportsLinuxInodeFlags = true
        #else
            static let supportsLinuxInodeFlags = false
        #endif

    }

}
