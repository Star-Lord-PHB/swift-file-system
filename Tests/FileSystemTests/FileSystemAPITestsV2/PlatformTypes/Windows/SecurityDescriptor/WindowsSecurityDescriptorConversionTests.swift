#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("Security descriptor conversion")
    struct WindowsSecurityDescriptorConversionTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsSecurityDescriptorConversionTests {

    private static func makeSampleDescriptor() -> WindowsAbsoluteSecurityDescriptor {
        .init(
            control: [.daclProtected],
            dacl: .acl(.init(entries: [.init(permission: .readData, trustee: .everyone)])),
            owner: .administrators,
            group: .system
        )
    }


    @Test
    func `makeSelfRelative sets the self-relative bit and keeps the members`() {

        let selfRelativeDescriptor = Self.makeSampleDescriptor().makeSelfRelative()
        let (control, revision) = selfRelativeDescriptor.control

        #expect(control.contains(.selfRelative))
        #expect(control.contains(.daclProtected))
        #expect(revision == DWORD(SECURITY_DESCRIPTOR_REVISION))

        let ownerSidString = selfRelativeDescriptor.owner?.sid.string
        let groupSidString = selfRelativeDescriptor.group?.sid.string

        #expect(ownerSidString == "S-1-5-32-544")
        #expect(groupSidString == "S-1-5-18")

        selfRelativeDescriptor.withUnsafeSdPtr { descriptorPointer in
            #expect(IsValidSecurityDescriptor(descriptorPointer))
        }

    }


    @Test
    func `Round trip through self-relative preserves the descriptor`() {

        let roundTripped = Self.makeSampleDescriptor().makeSelfRelative().makeAbsolute()

        #expect(roundTripped.control.contains(.daclProtected))
        #expect(roundTripped.control.contains(.selfRelative) == false)
        #expect(roundTripped.owner == WindowsSid.administrators)
        #expect(roundTripped.group == WindowsSid.system)

        let sidStrings = roundTripped.view.dacl?.map { $0.permission.sid.string }

        #expect(sidStrings == ["S-1-1-0"])

    }


    @Test
    func `DACL state survives the absolute round trip`() {

        let aclRoundTrip = Self.makeSampleDescriptor().makeSelfRelative().makeAbsolute()

        #expect(aclRoundTrip.dacl.case == .acl)

        let nullRoundTrip = WindowsAbsoluteSecurityDescriptor(dacl: .null).makeSelfRelative().makeAbsolute()

        #expect(nullRoundTrip.dacl.isNull == true)
        #expect(nullRoundTrip.control.contains(.daclPresent))

        let absentRoundTrip = WindowsAbsoluteSecurityDescriptor(dacl: .absent).makeSelfRelative().makeAbsolute()

        #expect(absentRoundTrip.dacl.isAbsent == true)
        #expect(absentRoundTrip.control.contains(.daclPresent) == false)

    }


    @Test
    func `fullyParsedDescriptor reports the members as values`() {

        let parsed = Self.makeSampleDescriptor().makeSelfRelative().fullyParsedDescriptor()

        #expect(parsed.revision == BYTE(SECURITY_DESCRIPTOR_REVISION))
        #expect(parsed.owner == "S-1-5-32-544")
        #expect(parsed.group == "S-1-5-18")
        #expect(parsed.control.contains(.daclProtected))
        #expect(parsed.sacl == nil)

        #expect(parsed.dacl?.type == .dacl)
        #expect(parsed.dacl?.revision == BYTE(ACL_REVISION))
        #expect(parsed.dacl?.isDefaulted == false)
        #expect(parsed.dacl?.aceList.count == 1)
        #expect(parsed.dacl?.aceList.first?.type == .allow)
        #expect(parsed.dacl?.aceList.first?.mask == .readData)
        #expect(parsed.dacl?.aceList.first?.sid == "S-1-1-0")

    }


    @Test
    func `Parsing the same descriptor twice compares equal`() {

        let selfRelativeDescriptor = Self.makeSampleDescriptor().makeSelfRelative()

        let firstParse = selfRelativeDescriptor.fullyParsedDescriptor()
        let secondParse = selfRelativeDescriptor.fullyParsedDescriptor()

        #expect(firstParse == secondParse)
        #expect(firstParse.hashValue == secondParse.hashValue)

    }


    @Test
    func `View reports the same members as its descriptor`() {

        let descriptor = Self.makeSampleDescriptor()
        let view = descriptor.view

        #expect(view.revision == descriptor.revision)
        #expect(view.control == descriptor.control)

        #expect(view.owner?.string == "S-1-5-32-544")
        #expect(view.dacl?.aceCount == 1)
        #expect((view.sacl == nil) == true)

    }

}

#endif
