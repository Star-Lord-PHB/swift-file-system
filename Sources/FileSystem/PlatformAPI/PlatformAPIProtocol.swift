

public protocol PlatformAPIProtocol {

    init()

    func accountName(for identity: PlatformIdentity) throws(FileError) -> String?

    #if canImport(WinSDK)
    func identity(forAccountName name: String) throws(FileError) -> PlatformIdentity?
    #else 
    func identity(forAccountName name: String, kind: PlatformIdentity.Kind) throws(FileError) -> PlatformIdentity?
    #endif

    func currentIdentity() throws(FileError) -> PlatformIdentity

    #if canImport(WinSDK)
    func effectiveAccessMask(
        for identity: PlatformIdentity, 
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(FileError) -> WindowsAccessMask

    func effectiveAccessMaskForCurrentProcess(
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(FileError) -> WindowsAccessMask
    #endif 

}