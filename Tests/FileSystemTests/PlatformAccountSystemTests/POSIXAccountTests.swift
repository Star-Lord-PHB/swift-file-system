#if !canImport(WinSDK)

import Testing
import SwiftFileSystem


extension PlatformAccountSystemTests {

    @Suite("POSIX accounts")
    struct POSIXAccountTests {}

}



extension PlatformAccountSystemTests.POSIXAccountTests {

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


    @Test(arguments: [
        ("root",            .init(rawId: 0, platformKind: .user),       .all),
        ("sys",             .init(rawId: 3, platformKind: .user),       .linux),
        ("daemon",          .init(rawId: 1, platformKind: .user),       .linux),
        ("users",           .init(rawId: 100, platformKind: .group),    .linux),
        ("bin",             .init(rawId: 2, platformKind: .user),       .linux),
        ("wheel",           .init(rawId: 0, platformKind: .group),      .darwin),
        ("staff",           .init(rawId: 20, platformKind: .group),     .darwin),
        ("_windowserver",   .init(rawId: 88, platformKind: .user),      .darwin),
        ("_mdnsresponder",  .init(rawId: 65, platformKind: .user),      .darwin),
        // MARK: TODO: Add some BSD-specific accounts?
    ] as [(String, PlatformIdentity, PosixPlatform)])
    func `Account name resolves to identity`(
        _ name: String, _ identity: PlatformIdentity, _ platform: PosixPlatform
    ) throws {

        guard platform.contains(.current) else { return }

        let queriedIdentity = try PlatformAccountSystem().identity(forAccountName: name)

        #expect(queriedIdentity == identity)

    }


    @Test(arguments: [
        (.init(rawId: 0, platformKind: .user),      "root",             .all),
        (.init(rawId: 3, platformKind: .user),      "sys",              .linux),
        (.init(rawId: 1, platformKind: .user),      "daemon",           .linux),
        (.init(rawId: 100, platformKind: .group),   "users",            .linux),
        (.init(rawId: 2, platformKind: .user),      "bin",              .linux),
        (.init(rawId: 0, platformKind: .group),     "wheel",            .darwin),
        (.init(rawId: 20, platformKind: .group),    "staff",            .darwin),
        (.init(rawId: 88, platformKind: .user),     "_windowserver",    .darwin),
        (.init(rawId: 65, platformKind: .user),     "_mdnsresponder",   .darwin),
    ] as [(PlatformIdentity, String, PosixPlatform)])
    func `Identity resolves to account name`(
        _ identity: PlatformIdentity, _ name: String, _ platform: PosixPlatform
    ) throws {

        guard platform.contains(.current) else { return }

        let queriedName = try PlatformAccountSystem().accountName(for: identity)

        #expect(queriedName == name)

    }

}

#endif
