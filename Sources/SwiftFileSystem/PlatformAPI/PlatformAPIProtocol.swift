import FileSystemCore


public protocol PlatformAPIProtocol {

    init()

    func accountName(for identity: PlatformIdentity) throws(PlatformError) -> String?
    
    func identity(
        forAccountName name: String,
        resolvePreference: PlatformIdentity.AccountNameResolvePreference
    ) throws(PlatformError) -> PlatformIdentity?

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
