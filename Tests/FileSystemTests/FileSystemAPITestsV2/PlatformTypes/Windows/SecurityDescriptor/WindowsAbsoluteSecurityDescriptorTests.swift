#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("Absolute security descriptor")
    struct WindowsAbsoluteSecurityDescriptorTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsAbsoluteSecurityDescriptorTests {

    private static func makeSampleDacl() -> WindowsRawAcl {
        .init(entries: [.init(permission: .readData, trustee: .everyone)])
    }

    @Test
    func `Initializer stores the descriptor members`() {

        let descriptor = WindowsAbsoluteSecurityDescriptor(
            control: [.daclProtected],
            dacl: Self.makeSampleDacl(),
            owner: .administrators,
            group: .system
        )
        #expect(descriptor.revision == DWORD(SECURITY_DESCRIPTOR_REVISION))
        #expect(descriptor.control.contains(.daclProtected))
        #expect(descriptor.control.contains(.daclPresent))
        #expect(descriptor.control.contains(.selfRelative) == false)
        #expect(descriptor.owner == WindowsSid.administrators)
        #expect(descriptor.group == WindowsSid.system)
        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == ["S-1-1-0"])

    }


    @Test
    func `Control initializer keeps only the writable bits`() {

        let requestedControl = WindowsSecurityDescriptorControl(
            unsafeRawValue: SECURITY_DESCRIPTOR_CONTROL(SE_OWNER_DEFAULTED)
                | SECURITY_DESCRIPTOR_CONTROL(SE_DACL_PROTECTED)
        )

        let descriptor = WindowsAbsoluteSecurityDescriptor(control: requestedControl)

        #expect(descriptor.control.contains(.daclProtected))
        #expect(descriptor.control.contains(.ownerDefaulted) == false)

    }


    // NOTE: this initializer always marks both ACLs present, so a nil DACL becomes the
    // present-but-NULL shape rather than an absent one. The absent state only arises from a
    // descriptor that never had a DACL set; see the ACL state suite.
    @Test
    func `Nil DACL installs a present NULL DACL`() {

        let descriptor = WindowsAbsoluteSecurityDescriptor(dacl: nil)

        #expect(descriptor.control.contains(.daclPresent))
        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == nil)

    }


    @Test
    func `addDaclEntries merges into the existing DACL`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(dacl: Self.makeSampleDacl())

        descriptor.addDaclEntries([.init(permission: .delete, trustee: .administrators)])

        let sidStrings = descriptor.view.dacl?.map { $0.permission.sid.string }

        #expect(sidStrings?.count == 2)
        #expect(sidStrings?.contains("S-1-1-0") == true)
        #expect(sidStrings?.contains("S-1-5-32-544") == true)

    }


    @Test
    func `addDaclEntries creates a DACL when there is none`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(dacl: nil)

        descriptor.addDaclEntries([.init(permission: .readData, trustee: .everyone)])

        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == ["S-1-1-0"])

    }


    @Test
    func `removeDacl, removeOwner and removeGroup clear their members`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(
            dacl: Self.makeSampleDacl(),
            owner: .administrators,
            group: .system
        )

        #expect(descriptor.owner == WindowsSid.administrators)
        #expect(descriptor.group == WindowsSid.system)

        descriptor.removeDacl()
        descriptor.removeOwner()
        descriptor.removeGroup()

        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == nil)
        #expect(descriptor.owner == nil)
        #expect(descriptor.group == nil)

    }


    @Test
    func `takeDacl hands the ACL over to the caller`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(dacl: Self.makeSampleDacl())
        let takenAcl = descriptor.takeDacl()

        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == nil)

        // `WindowsRawAcl` is `~Copyable`, so the macro cannot optional-chain into it here
        // without consuming it.
        if let takenAcl {
            #expect(takenAcl.aceCount == 1)
            #expect(takenAcl[0].permission.sid.string == "S-1-1-0")
        } else {
            Issue.record("A present DACL should be handed over by takeDacl")
        }

    }


    @Test
    func `withUnsafeSdPtr yields a valid descriptor`() {

        let descriptor = WindowsAbsoluteSecurityDescriptor(dacl: Self.makeSampleDacl())

        descriptor.withUnsafeSdPtr { descriptorPointer in
            #expect(IsValidSecurityDescriptor(descriptorPointer))
        }

    }

}

#endif
