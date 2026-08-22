#if canImport(WinSDK)

import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore


extension PlatformAPITest {
    
    @Suite("Windows Accounts")
    struct WindowsAccounts {}
    
}



extension PlatformAPITest.WindowsAccounts {
    
    @Test(
        "Account Name -> Identity",
        arguments: [
            ("Everyone", .init(rawId: WindowsSid.everyone, platformKind: .wellknownGroup)),
            ("SYSTEM", .init(rawId: WindowsSid.system, platformKind: .wellknownGroup)),
            ("Administrators", .init(rawId: WindowsSid.administrators, platformKind: .alias)),
            ("Authenticated Users", .init(rawId: WindowsSid.authenticatedUsers, platformKind: .wellknownGroup)),
            ("Guests", .init(rawId: .init(string: "S-1-5-32-546")!, platformKind: .alias)),
        ] as [(String, PlatformIdentity)]
    )
    func accountNameToIdentity(_ name: String, _ identity: PlatformIdentity) async throws {
        let queriedIdentity = try PlatformAccountSystem().identity(forAccountName: name)
        #expect(queriedIdentity == identity)
    }
    
    
    @Test(
        "Identity -> Account Name",
        arguments: [
            (.init(rawId: WindowsSid.everyone, platformKind: .wellknownGroup), "Everyone"),
            (.init(rawId: WindowsSid.system, platformKind: .wellknownGroup), "SYSTEM"),
            (.init(rawId: WindowsSid.administrators, platformKind: .alias), "Administrators"),
            (.init(rawId: WindowsSid.authenticatedUsers, platformKind: .wellknownGroup), "Authenticated Users"),
            (.init(rawId: .init(string: "S-1-5-32-546")!, platformKind: .alias), "Guests"),
        ] as [(PlatformIdentity, String)]
    )
    func identityToAccountName(_ identity: PlatformIdentity, _ name: String) async throws {
        let queriedName = try PlatformAccountSystem().accountName(for: identity)
        #expect(queriedName == name)
    }
    
}

#endif
