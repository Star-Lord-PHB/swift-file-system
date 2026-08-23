#if canImport(WinSDK)

import Testing
import SwiftFileSystem


extension PlatformAccountSystemTests {

    @Suite("Windows accounts")
    struct WindowsAccountTests {}

}



extension PlatformAccountSystemTests.WindowsAccountTests {

    @Test(arguments: [
        ("Everyone", .init(rawId: WindowsSid.everyone, platformKind: .wellknownGroup)),
        ("SYSTEM", .init(rawId: WindowsSid.system, platformKind: .wellknownGroup)),
        ("Administrators", .init(rawId: WindowsSid.administrators, platformKind: .alias)),
        ("Authenticated Users", .init(rawId: WindowsSid.authenticatedUsers, platformKind: .wellknownGroup)),
        ("Guests", .init(rawId: .init(string: "S-1-5-32-546")!, platformKind: .alias)),
    ] as [(String, PlatformIdentity)])
    func `Account name resolves to identity`(_ name: String, _ identity: PlatformIdentity) throws {

        let queriedIdentity = try PlatformAccountSystem().identity(forAccountName: name)

        #expect(queriedIdentity == identity)

    }


    @Test(arguments: [
        (.init(rawId: WindowsSid.everyone, platformKind: .wellknownGroup), "Everyone"),
        (.init(rawId: WindowsSid.system, platformKind: .wellknownGroup), "SYSTEM"),
        (.init(rawId: WindowsSid.administrators, platformKind: .alias), "Administrators"),
        (.init(rawId: WindowsSid.authenticatedUsers, platformKind: .wellknownGroup), "Authenticated Users"),
        (.init(rawId: .init(string: "S-1-5-32-546")!, platformKind: .alias), "Guests"),
    ] as [(PlatformIdentity, String)])
    func `Identity resolves to account name`(_ identity: PlatformIdentity, _ name: String) throws {

        let queriedName = try PlatformAccountSystem().accountName(for: identity)

        #expect(queriedName == name)

    }

}

#endif
