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
            dacl: .acl(Self.makeSampleDacl()),
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


    @Test
    func `Null DACL state installs a present NULL DACL`() {

        let descriptor = WindowsAbsoluteSecurityDescriptor(dacl: .null)

        #expect(descriptor.control.contains(.daclPresent))
        #expect(descriptor.dacl.isNull == true)
        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == nil)

    }


    @Test
    func `Both ACL slots default to the absent state`() {

        let descriptor = WindowsAbsoluteSecurityDescriptor()

        #expect(descriptor.dacl.isAbsent == true)
        #expect(descriptor.sacl.isAbsent == true)
        #expect(descriptor.control.contains(.daclPresent) == false)
        #expect(descriptor.control.contains(.saclPresent) == false)
        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == nil)

    }


    @Test
    func `SACL slot walks through the three states`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(sacl: .acl(Self.makeSampleDacl()))

        #expect(descriptor.control.contains(.saclPresent))
        #expect(descriptor.sacl.case == .acl)
        #expect(descriptor.view.sacl?.map { $0.permission.sid.string } == ["S-1-1-0"])

        descriptor.sacl = .null

        #expect(descriptor.control.contains(.saclPresent))
        #expect(descriptor.sacl.isNull == true)
        #expect((descriptor.view.sacl == nil) == true)

        descriptor.sacl = .absent

        #expect(descriptor.control.contains(.saclPresent) == false)
        #expect(descriptor.sacl.isAbsent == true)

    }


    @Test
    func `dacl.addEntries merges into the existing DACL`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(dacl: .acl(Self.makeSampleDacl()))

        descriptor.dacl.addEntries([.init(permission: .delete, trustee: .administrators)])

        let sidStrings = descriptor.view.dacl?.map { $0.permission.sid.string }

        #expect(sidStrings?.count == 2)
        #expect(sidStrings?.contains("S-1-1-0") == true)
        #expect(sidStrings?.contains("S-1-5-32-544") == true)

    }


    @Test
    func `dacl.addEntries creates a DACL when there is none`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(dacl: .null)

        descriptor.dacl.addEntries([.init(permission: .readData, trustee: .everyone)])

        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == ["S-1-1-0"])

    }


    @Test
    func `Assigning absent DACL, removeOwner and removeGroup clear their members`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(
            dacl: .acl(Self.makeSampleDacl()),
            owner: .administrators,
            group: .system
        )

        #expect(descriptor.owner == WindowsSid.administrators)
        #expect(descriptor.group == WindowsSid.system)

        descriptor.dacl = .absent
        descriptor.removeOwner()
        descriptor.removeGroup()

        #expect(descriptor.control.contains(.daclPresent) == false)
        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == nil)
        #expect(descriptor.owner == nil)
        #expect(descriptor.group == nil)

    }


    @Test
    func `dacl.take hands the ACL over and leaves the requested state`() {

        var descriptor = WindowsAbsoluteSecurityDescriptor(dacl: .acl(Self.makeSampleDacl()))
        let takenAcl = descriptor.dacl.take(leaving: .absent)

        #expect(descriptor.dacl.isAbsent == true)
        #expect(descriptor.view.dacl?.map { $0.permission.sid.string } == nil)

        // `WindowsRawAcl` is `~Copyable`, so the macro cannot optional-chain into it here
        // without consuming it.
        if let takenAcl {
            #expect(takenAcl.aceCount == 1)
            #expect(takenAcl[0].permission.sid.string == "S-1-1-0")
        } else {
            Issue.record("A present DACL should be handed over by take(leaving:)")
        }

    }


    @Test
    func `withUnsafeSdPtr yields a valid descriptor`() {

        let descriptor = WindowsAbsoluteSecurityDescriptor(dacl: .acl(Self.makeSampleDacl()))

        descriptor.withUnsafeSdPtr { descriptorPointer in
            #expect(IsValidSecurityDescriptor(descriptorPointer))
        }

    }

}

#endif
