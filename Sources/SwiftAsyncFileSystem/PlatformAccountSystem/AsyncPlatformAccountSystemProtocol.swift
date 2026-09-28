import FileSystemCore


/// Protocol of APIs for querying the platform's user/group account database.
public protocol AsyncPlatformAccountSystemProtocol: Sendable {

    /// Gets the account name for a given identity.
    /// - Parameter identity: The identity to look up.
    @concurrent
    func accountName(for identity: PlatformIdentity) async throws(PlatformError) -> String?

    /// Gets the identity for a given account name.
    /// - Parameters:
    ///   - name: The account name to look up.
    ///   - resolvePreference: The preference for resolving the account name, either user or group. This 
    ///                        option is only meaningful on Posix where users and groups may share the same
    ///                        name.
    @concurrent
    func identity(
        forAccountName name: String,
        resolvePreference: PlatformIdentity.AccountNameResolvePreference
    ) async throws(PlatformError) -> PlatformIdentity?

    /// Gets the identity of the current process.
    @concurrent
    func currentIdentity() async throws(PlatformError) -> PlatformIdentity

}
