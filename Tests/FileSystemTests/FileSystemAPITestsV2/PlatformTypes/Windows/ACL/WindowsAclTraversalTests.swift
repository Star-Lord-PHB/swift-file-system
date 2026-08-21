#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("ACL traversal")
    struct WindowsAclTraversalTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsAclTraversalTests {

    /// Three entries that land in canonical order as deny, allow, allow.
    private static func makeSampleAcl() -> WindowsRawAcl {
        WindowsRawAcl(entries: [
            .init(permission: .readData, accessMode: .grantAccess, trustee: .everyone),
            .init(permission: .writeData, accessMode: .denyAccess, trustee: .system),
            .init(permission: .delete, accessMode: .grantAccess, trustee: .administrators)
        ])
    }


    @Test
    func `subscript returns the ACEs in index order`() {

        let acl = Self.makeSampleAcl()

        #expect(acl.aceCount == 3)
        #expect(acl[0].type == .deny)
        #expect(acl[0].permission.sid.string == "S-1-5-18")
        #expect(acl[1].type == .allow)
        #expect(acl[1].permission.sid.string == "S-1-1-0")
        #expect(acl[2].type == .allow)
        #expect(acl[2].permission.sid.string == "S-1-5-32-544")

    }


    @Test
    func `forEach and map visit every ACE in order`() {

        let acl = Self.makeSampleAcl()

        var visitedSidStrings = [] as [String]
        acl.forEach { ace in
            visitedSidStrings.append(ace.permission.sid.string)
        }

        #expect(visitedSidStrings == ["S-1-5-18", "S-1-1-0", "S-1-5-32-544"])
        #expect(acl.map { $0.type } == [.deny, .allow, .allow])

    }


    @Test
    func `compactMap drops the entries the transform rejects`() {

        let acl = Self.makeSampleAcl()

        let allowedSidStrings = acl.compactMap { ace in
            ace.type == .allow ? ace.permission.sid.string : nil
        }

        #expect(allowedSidStrings == ["S-1-1-0", "S-1-5-32-544"])

    }


    @Test
    func `reduce accumulates over every ACE`() {

        let acl = Self.makeSampleAcl()

        let combinedMask = acl.reduce(WindowsAccessMask()) { mask, ace in
            mask.union(ace.permission.mask)
        }

        #expect(combinedMask == [.readData, .writeData, .delete])

    }


    @Test
    func `first returns the leading ACE`() {

        let acl = Self.makeSampleAcl()

        var leadingSidString: String?
        if let leadingAce = acl.first {
            leadingSidString = leadingAce.permission.sid.string
        }

        #expect(leadingSidString == "S-1-5-18")

    }


    @Test
    func `first with a predicate finds a matching ACE or returns nil`() {

        let acl = Self.makeSampleAcl()

        var matchedMask: WindowsAccessMask?
        if let matchedAce = acl.first(where: { $0.permission.sid.string == "S-1-5-32-544" }) {
            matchedMask = matchedAce.permission.mask
        }

        #expect(matchedMask == .delete)

        var matchedAudit = false
        if let _ = acl.first(where: { $0.type == .audit }) {
            matchedAudit = true
        }

        #expect(matchedAudit == false)

    }


    @Test
    func `Traversal over an empty ACL yields nothing`() {

        let acl = WindowsRawAcl()

        var visitCount = 0
        acl.forEach { _ in visitCount += 1 }

        #expect(visitCount == 0)
        #expect(acl.map { $0.type }.isEmpty)

        var hasLeadingAce = false
        if let _ = acl.first {
            hasLeadingAce = true
        }

        #expect(hasLeadingAce == false)

    }

}

#endif
