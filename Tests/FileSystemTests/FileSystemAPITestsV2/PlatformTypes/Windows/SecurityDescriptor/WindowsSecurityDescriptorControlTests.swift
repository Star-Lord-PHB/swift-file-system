#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("Security descriptor control")
    struct WindowsSecurityDescriptorControlTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsSecurityDescriptorControlTests {

    @Test
    func `Array literal unions the writable flags`() {

        let control: WindowsSecurityDescriptorControl = [.daclProtected, .saclProtected]
        let expected = SECURITY_DESCRIPTOR_CONTROL(SE_DACL_PROTECTED)
            | SECURITY_DESCRIPTOR_CONTROL(SE_SACL_PROTECTED)

        #expect(control.rawValue == expected)
        #expect(WindowsSecurityDescriptorControl(rawValue: .daclProtected).rawValue
            == SECURITY_DESCRIPTOR_CONTROL(SE_DACL_PROTECTED))
        #expect(WindowsSecurityDescriptorControl(unsafeRawValue: expected).rawValue == expected)

    }


    @Test
    func `contains requires every requested bit`() {

        let control: WindowsSecurityDescriptorControl = [.daclProtected]
        let bothControl: WindowsSecurityDescriptorControl = [.daclProtected, .daclAutoInherited]

        #expect(control.contains(.daclProtected))
        #expect(control.contains(.daclAutoInherited) == false)
        #expect(control.contains([.daclProtected, .daclAutoInherited]) == false)
        #expect(bothControl.contains([.daclProtected, .daclAutoInherited]))
        #expect(control.contains([]))

    }


    @Test
    func `Union and intersection combine writable flags`() {

        let control: WindowsSecurityDescriptorControl = [.daclProtected]

        let united = control.union(.saclProtected)
        let intersected = united.intersection(.daclProtected)

        #expect(united.contains(.daclProtected))
        #expect(united.contains(.saclProtected))
        #expect(intersected.contains(.daclProtected))
        #expect(intersected.contains(.saclProtected) == false)

        var mutated = control
        mutated.insert(.saclProtected)
        #expect(mutated.rawValue == united.rawValue)

        mutated = control
        mutated.formUnion(.saclProtected)
        #expect(mutated.rawValue == united.rawValue)

        mutated.formIntersection(.daclProtected)
        #expect(mutated.rawValue == intersected.rawValue)

    }


    @Test
    func `Removing and subtracting clear writable flags`() {

        let control: WindowsSecurityDescriptorControl = [.daclProtected, .saclProtected]
        let removed = control.removing(.saclProtected)

        #expect(removed.contains(.daclProtected))
        #expect(removed.contains(.saclProtected) == false)
        #expect(control.subtracting(.saclProtected).rawValue == removed.rawValue)

        var mutated = control
        mutated.remove(.saclProtected)
        #expect(mutated.rawValue == removed.rawValue)

        mutated = control
        mutated.subtract(.saclProtected)
        #expect(mutated.rawValue == removed.rawValue)

    }


    @Test
    func `Control constants carry their writable bit`() {

        #expect(WindowsSecurityDescriptorControl.daclProtected.contains(.daclProtected))
        #expect(WindowsSecurityDescriptorControl.saclProtected.contains(.saclProtected))
        #expect(WindowsSecurityDescriptorControl.daclAutoInheritReq.contains(.daclAutoInheritReq))
        #expect(WindowsSecurityDescriptorControl.saclAutoInheritReq.contains(.saclAutoInheritReq))

    }


    @Test(
        arguments: [
            (.daclProtected, SE_DACL_PROTECTED),
            (.saclProtected, SE_SACL_PROTECTED),
            (.daclAutoInheritReq, SE_DACL_AUTO_INHERIT_REQ),
            (.saclAutoInheritReq, SE_SACL_AUTO_INHERIT_REQ),
            (.daclAutoInherited, SE_DACL_AUTO_INHERITED),
            (.saclAutoInherited, SE_SACL_AUTO_INHERITED)
        ] as [(WindowsSecurityDescriptorControl.WrittableControlFlags, Int32)]
    )
    func `Writable control flags map to native flags`(
        _ flag: WindowsSecurityDescriptorControl.WrittableControlFlags,
        _ rawValue: Int32
    ) {

        #expect(flag.rawValue == SECURITY_DESCRIPTOR_CONTROL(rawValue))

    }


    @Test
    func `All contains every writable flag`() {

        let expected: WindowsSecurityDescriptorControl.WrittableControlFlags = [
            .daclProtected, .saclProtected, .daclAutoInheritReq,
            .saclAutoInheritReq, .daclAutoInherited, .saclAutoInherited
        ]

        #expect(WindowsSecurityDescriptorControl.WrittableControlFlags.all == expected)

    }


    @Test
    func `Or operator unions two writable flags`() {

        let combined: WindowsSecurityDescriptorControl.WrittableControlFlags =
            .daclProtected | .saclProtected

        #expect(combined.rawValue == SECURITY_DESCRIPTOR_CONTROL(SE_DACL_PROTECTED | SE_SACL_PROTECTED))

    }


    @Test(
        arguments: [
            (.daclAutoInheritReq, SE_DACL_AUTO_INHERIT_REQ),
            (.daclAutoInherited, SE_DACL_AUTO_INHERITED),
            (.daclDefaulted, SE_DACL_DEFAULTED),
            (.daclPresent, SE_DACL_PRESENT),
            (.daclProtected, SE_DACL_PROTECTED),
            (.groupDefaulted, SE_GROUP_DEFAULTED),
            (.ownerDefaulted, SE_OWNER_DEFAULTED),
            (.rmControlValid, SE_RM_CONTROL_VALID),
            (.saclAutoInheritReq, SE_SACL_AUTO_INHERIT_REQ),
            (.saclAutoInherited, SE_SACL_AUTO_INHERITED),
            (.saclDefaulted, SE_SACL_DEFAULTED),
            (.saclPresent, SE_SACL_PRESENT),
            (.saclProtected, SE_SACL_PROTECTED),
            (.selfRelative, SE_SELF_RELATIVE)
        ] as [(WindowsSecurityDescriptorControl.ReadOnlyControlFlags, Int32)]
    )
    func `Read-only control flags map to native flags`(
        _ flag: WindowsSecurityDescriptorControl.ReadOnlyControlFlags,
        _ rawValue: Int32
    ) {

        #expect(flag.rawValue == SECURITY_DESCRIPTOR_CONTROL(rawValue))

    }

}

#endif
