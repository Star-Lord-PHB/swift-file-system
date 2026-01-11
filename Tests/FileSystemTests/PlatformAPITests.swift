import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    @Suite
    final class PlatformAPITest: FileSystemTest {}

}



extension FileSystemTest.PlatformAPITest {

    #if canImport(WinSDK)

    @Test(
        "Account Name -> Identity",
        arguments: [
            ("Everyone", .init(rawId: WindowsSid.everyone)),
            ("SYSTEM", .init(rawId: WindowsSid.system)),
            ("Administrators", .init(rawId: WindowsSid.administrators)),
            ("Authenticated Users", .init(rawId: WindowsSid.authenticatedUsers)),
            ("Guests", .init(rawId: .init(string: "S-1-5-32-546")!)),
        ] as [(String, PlatformIdentity)]
    )
    func accountNameToIdentity(_ name: String, _ identity: PlatformIdentity) async throws {
        let queriedIdentity = try PlatformAPI().identity(forAccountName: name)
        #expect(queriedIdentity == identity)
    }


    @Test(
        "Identity -> Account Name",
        arguments: [
            (.init(rawId: WindowsSid.everyone), "Everyone"),
            (.init(rawId: WindowsSid.system), "SYSTEM"),
            (.init(rawId: WindowsSid.administrators), "Administrators"),
            (.init(rawId: WindowsSid.authenticatedUsers), "Authenticated Users"),
            (.init(rawId: .init(string: "S-1-5-32-546")!), "Guests"),
        ] as [(PlatformIdentity, String)]
    )
    func identityToAccountName(_ identity: PlatformIdentity, _ name: String) async throws {
        let queriedName = try PlatformAPI().accountName(for: identity)
        #expect(queriedName == name)
    }

    #else 

    struct PosixPlatform: OptionSet, Sendable {
        let rawValue: Int
        static var current: Self {
            #if canImport(Darwin)
            .darwin
            #elseif os(FreeBSD) || os(OpenBSD)
            .bsd
            #else
            .linux
            #endif
        }
        static let darwin = Self(rawValue: 1 << 0)
        static let bsd    = Self(rawValue: 1 << 1)
        static let linux  = Self(rawValue: 1 << 2)
        static var all: Self { [.darwin, .bsd, .linux] }
    }

    @Test(
        "Account Name -> Identity",
        arguments: [
            ("root",            .init(rawId: 0, kind: .user),       .all),
            ("sys",             .init(rawId: 3, kind: .user),       .linux),
            ("daemon",          .init(rawId: 1, kind: .user),       .linux),
            ("users",           .init(rawId: 100, kind: .group),    .linux),
            ("bin",             .init(rawId: 2, kind: .user),       .linux),
            ("sys",             .init(rawId: 3, kind: .user),       .linux),
            ("wheel",           .init(rawId: 0, kind: .group),      .darwin),   
            ("staff",           .init(rawId: 20, kind: .group),     .darwin),
            ("_windowserver",   .init(rawId: 88, kind: .user),      .darwin),
            ("_mdnsresponder",  .init(rawId: 65, kind: .user),      .darwin),
            // MARK: TODO: Add some BSD-specific accounts?
        ] as [(String, PlatformIdentity, PosixPlatform)]
    )
    func accountNameToIdentity(_ name: String, _ identity: PlatformIdentity, _ platform: PosixPlatform) async throws {
        guard platform.contains(.current) else { return }
        let queriedIdentity = try PlatformAPI().identity(forAccountName: name, kind: identity.kind)
        #expect(queriedIdentity == identity)
    }


    @Test(
        "Identity -> Account Name",
        arguments: [
            (.init(rawId: 0, kind: .user),      "root",             .all),
            (.init(rawId: 3, kind: .user),      "sys",              .linux),
            (.init(rawId: 1, kind: .user),      "daemon",           .linux),
            (.init(rawId: 100, kind: .group),   "users",            .linux),
            (.init(rawId: 2, kind: .user),      "bin",              .linux),
            (.init(rawId: 0, kind: .group),     "wheel",            .darwin),   
            (.init(rawId: 20, kind: .group),    "staff",            .darwin),
            (.init(rawId: 88, kind: .user),     "_windowserver",    .darwin),
            (.init(rawId: 65, kind: .user),     "_mdnsresponder",   .darwin),
        ] as [(PlatformIdentity, String, PosixPlatform)]
    )
    func identityToAccountName(_ identity: PlatformIdentity, _ name: String, _ platform: PosixPlatform) async throws {
        guard platform.contains(.current) else { return }
        let queriedName = try PlatformAPI().accountName(for: identity)
        #expect(queriedName == name)
    }

    #endif 

}