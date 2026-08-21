#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("ACL")
    struct WindowsRawAclTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsRawAclTests {

    @Test
    func `Empty ACL has no entries`() {

        let acl = WindowsRawAcl()

        #expect(acl.aceCount == 0)
        #expect(acl.revision == BYTE(ACL_REVISION))
        acl.withUnsafePACL { aclPointer in
            #expect(IsValidAcl(aclPointer))
        }

        let emptyAcl = WindowsRawAcl.emptyAcl

        #expect(emptyAcl.aceCount == 0)

    }


    @Test
    func `Entries become ACEs carrying their trustee and mask`() {

        let acl = WindowsRawAcl(entries: [
            .init(permission: [.readData, .readAttributes], trustee: .everyone)
        ])

        #expect(acl.aceCount == 1)

        let ace = acl[0]

        #expect(ace.type == .allow)
        #expect(ace.permission.mask == [.readData, .readAttributes])
        #expect(ace.permission.sid.string == "S-1-1-0")

    }


    // NOTE: entries go through `SetEntriesInAclW`, which writes the ACL in canonical order
    // rather than in the order given, so deny entries land ahead of allow entries.
    @Test
    func `Deny entries are written ahead of allow entries`() {

        let acl = WindowsRawAcl(entries: [
            .init(permission: .readData, accessMode: .grantAccess, trustee: .everyone),
            .init(permission: .writeData, accessMode: .denyAccess, trustee: .system)
        ])

        #expect(acl.aceCount == 2)
        #expect(acl[0].type == .deny)
        #expect(acl[0].permission.sid.string == "S-1-5-18")
        #expect(acl[1].type == .allow)
        #expect(acl[1].permission.sid.string == "S-1-1-0")

    }


    @Test
    func `Inheritance reaches the ACE flags`() {

        let acl = WindowsRawAcl(entries: [
            .init(permission: .readData, inheritance: .allSubItems, trustee: .everyone)
        ])

        let flags = acl[0].flags

        #expect(flags.contains(.objectInherit))
        #expect(flags.contains(.containerInherit))
        #expect(flags.contains(.inheritOnly) == false)

    }


    @Test
    func `addEntries preserves existing entries`() {

        var acl = WindowsRawAcl(entries: [
            .init(permission: .readData, trustee: .everyone)
        ])

        acl.addEntries([.init(permission: .delete, trustee: .administrators)])

        #expect(acl.aceCount == 2)

        let sidStrings = acl.map { $0.permission.sid.string }

        #expect(sidStrings.contains("S-1-1-0"))
        #expect(sidStrings.contains("S-1-5-32-544"))

    }


    @Test
    func `ACE size covers the header, the mask and the SID`() {

        let acl = WindowsRawAcl(entries: [
            .init(permission: .readData, trustee: .everyone)
        ])
        let everyoneSid = WindowsSid.everyone
        let sidLength = everyoneSid.withUnsafePSid { GetLengthSid($0) }

        // An allow ACE stores the SID in place of the trailing SidStart field.
        let expectedSize = MemoryLayout<ACCESS_ALLOWED_ACE>.size
            - MemoryLayout<DWORD>.size
            + Int(sidLength)

        #expect(acl[0].size == WORD(expectedSize))

    }


    @Test
    func `View sees the same ACEs as its ACL`() {

        let acl = WindowsRawAcl(entries: [
            .init(permission: .readData, trustee: .everyone),
            .init(permission: .delete, trustee: .administrators)
        ])
        let view = acl.view

        #expect(view.revision == acl.revision)
        #expect(view.aceCount == acl.aceCount)
        #expect(view[0].permission.sid.string == acl[0].permission.sid.string)
        #expect(view[1].permission.sid.string == acl[1].permission.sid.string)

    }

}

#endif
