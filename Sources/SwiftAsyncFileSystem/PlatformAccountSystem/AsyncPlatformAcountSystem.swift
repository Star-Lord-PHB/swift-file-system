import SwiftFileSystem



/// APIs for querying the platform's user/group account database.
///
/// - Note: Lookups may reach out to directory services (e.g. a Windows domain
/// controller for domain SIDs) and can therefore block on the network.
public struct AsyncPlatformAccountSystem: AsyncPlatformAccountSystemProtocol {

    let syncAccountSystem: PlatformAccountSystem
    /// The executor for executing the operations
    public let executor: AsyncFileSystemExecutor

    public init(executor: AsyncFileSystemExecutor = .defaultExecutor) {
       self.executor = executor
       self.syncAccountSystem = .init()
    }

}



extension AsyncPlatformAccountSystem {

    @concurrent
    public func accountName(for identity: PlatformIdentity) async throws(PlatformError) -> String? {
        return try await executor.runCancellable { () throws(PlatformError) in
            try self.syncAccountSystem.accountName(for: identity)
        }
        .getThrowingPlatformError(operation: .queryAccountNameFromIdentity)
    }


    @concurrent
    public func identity(
        forAccountName name: String,
        resolvePreference: PlatformIdentity.AccountNameResolvePreference = .preferUser
    ) async throws(PlatformError) -> PlatformIdentity? {
        return try await executor.runCancellable { () throws(PlatformError) in
            try self.syncAccountSystem.identity(forAccountName: name, resolvePreference: resolvePreference)
        }
        .getThrowingPlatformError(operation: .queryIdentityfromName)
    }


    @concurrent
    public func currentIdentity() async throws(PlatformError) -> PlatformIdentity {
        return try await executor.runCancellable { () throws(PlatformError) in
            try self.syncAccountSystem.currentIdentity()
        }
        .getThrowingPlatformError(operation: .queryCurrentIdentity)
    }

}
