import FileSystemCore


/// Queries the platform's user/group account database (POSIX passwd/group, Windows LSA).
///
/// Note that lookups may reach out to directory services (e.g. a Windows domain
/// controller for domain SIDs) and can therefore block on the network.
public struct PlatformAccountSystem: PlatformAccountSystemProtocol {

    public init() { }

}



extension PlatformAccountSystem {

    public func accountName(for identity: PlatformIdentity) throws(PlatformError) -> String? {
        return try catchLowLevelError(operation: .queryAccountNameFromIdentity) { () throws(LowLevelError) in
            try InternalPlatformAPI.accountName(for: identity)
        }
    }


    public func identity(
        forAccountName name: String,
        resolvePreference: PlatformIdentity.AccountNameResolvePreference = .preferUser
    ) throws(PlatformError) -> PlatformIdentity? {
        return try catchLowLevelError(operation: .queryIdentityfromName) { () throws(LowLevelError) in
            try InternalPlatformAPI.identity(forAccountName: name, resolvePreference: resolvePreference)
        }
    }


    public func currentIdentity() throws(PlatformError) -> PlatformIdentity {
        return try catchLowLevelError(operation: .queryCurrentIdentity) { () throws(LowLevelError) in
            try InternalPlatformAPI.currentIdentity()
        }
    }

}
