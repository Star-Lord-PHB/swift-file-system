import FileSystemCore


/// Protocol of APIs for querying the platform's user/group account database.
public protocol PlatformAccountSystemProtocol: Sendable {

    /// Gets the account name for a given identity.
    /// - Parameter identity: The identity to look up.
    func accountName(for identity: PlatformIdentity) throws(PlatformError) -> String?

    /// Gets the identity for a given account name.
    /// - Parameters:
    ///   - name: The account name to look up.
    ///   - resolvePreference: The preference for resolving the account name, either user or group. This 
    ///                        option is only meaningful on Posix where users and groups may share the same
    ///                        name.
    func identity(
        forAccountName name: String,
        resolvePreference: PlatformIdentity.AccountNameResolvePreference
    ) throws(PlatformError) -> PlatformIdentity?

    /// Gets the identity of the current process.
    func currentIdentity() throws(PlatformError) -> PlatformIdentity

}
