import FileSystemCore


public protocol PlatformAPIProtocol {

    init()

    func accountName(for identity: PlatformIdentity) throws(PlatformError) -> String?

    #if canImport(WinSDK)
    func identity(forAccountName name: String) throws(PlatformError) -> PlatformIdentity?
    #else 
    func identity(forAccountName name: String, kind: PlatformIdentity.Kind) throws(PlatformError) -> PlatformIdentity?
    #endif

    func currentIdentity() throws(PlatformError) -> PlatformIdentity

    #if canImport(WinSDK)
    func effectiveAccessMask(
        for identity: PlatformIdentity, 
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) -> WindowsAccessMask

    func effectiveAccessMaskForCurrentProcess(
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) -> WindowsAccessMask
    #endif 

}