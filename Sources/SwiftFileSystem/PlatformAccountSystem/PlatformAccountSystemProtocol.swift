import FileSystemCore


public protocol PlatformAccountSystemProtocol: Sendable {

    func accountName(for identity: PlatformIdentity) throws(PlatformError) -> String?

    func identity(
        forAccountName name: String,
        resolvePreference: PlatformIdentity.AccountNameResolvePreference
    ) throws(PlatformError) -> PlatformIdentity?

    func currentIdentity() throws(PlatformError) -> PlatformIdentity

}
