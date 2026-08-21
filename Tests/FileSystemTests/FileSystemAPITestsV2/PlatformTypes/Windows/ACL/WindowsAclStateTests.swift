#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("ACL state")
    struct WindowsAclStateTests {}

}



// The three states are only reachable through a security descriptor, so these tests build
// descriptors as fixtures. The descriptor API itself is covered by its own suite.
//
// `WindowsRawAclState` is `~Escapable`, which the `#expect` macro cannot take as the base of a
// member access, so its properties are read into locals before being asserted on.
extension PlatformTypesAPITests.WindowsSecurityTests.WindowsAclStateTests {

    /// A descriptor straight out of `InitializeSecurityDescriptor`, which leaves both the
    /// DACL and the SACL unset rather than present-and-NULL.
    private static func makeDescriptorWithoutAcls() -> WindowsSelfRelativeSecurityDescriptor {
        var absoluteDescriptor = SECURITY_DESCRIPTOR()
        InitializeSecurityDescriptor(&absoluteDescriptor, DWORD(SECURITY_DESCRIPTOR_REVISION))

        var size = 0 as DWORD
        _ = withUnsafeMutablePointer(to: &absoluteDescriptor) { descriptorPointer in
            MakeSelfRelativeSD(descriptorPointer, nil, &size)
        }
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<DWORD>.alignment
        )
        _ = withUnsafeMutablePointer(to: &absoluteDescriptor) { descriptorPointer in
            MakeSelfRelativeSD(descriptorPointer, buffer, &size)
        }

        return .init(unsafeOwningSdPtr: buffer, allocator: .swift)
    }


    private static func makeDescriptorWithDacl() -> WindowsSelfRelativeSecurityDescriptor {
        WindowsAbsoluteSecurityDescriptor(
            dacl: .init(entries: [.init(permission: .readData, trustee: .everyone)])
        ).makeSelfRelative()
    }


    private static func makeDescriptorWithNullDacl() -> WindowsSelfRelativeSecurityDescriptor {
        WindowsAbsoluteSecurityDescriptor(dacl: nil).makeSelfRelative()
    }


    @Test
    func `Unset DACL reports the absent state`() {

        let descriptor = Self.makeDescriptorWithoutAcls()
        let state = descriptor.dacl
        let stateCase = state.case
        let isAbsent = state.isAbsent
        let isNull = state.isNull
        let defaulted = state.defaulted

        #expect(stateCase == .absent)
        #expect(isAbsent)
        #expect(isNull == false)
        #expect(defaulted == nil)

    }


    @Test
    func `Null DACL is present without an ACL`() {

        let descriptor = Self.makeDescriptorWithNullDacl()
        let state = descriptor.dacl
        let stateCase = state.case
        let isAbsent = state.isAbsent
        let isNull = state.isNull
        let defaulted = state.defaulted

        #expect(stateCase == .null)
        #expect(isAbsent == false)
        #expect(isNull)
        #expect(defaulted == false)

    }


    @Test
    func `Present DACL exposes its ACEs`() {

        let descriptor = Self.makeDescriptorWithDacl()
        let state = descriptor.dacl
        let stateCase = state.case
        let isAbsent = state.isAbsent
        let isNull = state.isNull
        let defaulted = state.defaulted

        #expect(stateCase == .present)
        #expect(isAbsent == false)
        #expect(isNull == false)
        #expect(defaulted == false)

        var sidString: String?
        if let acl = state.value {
            #expect(acl.aceCount == 1)
            sidString = acl[0].permission.sid.string
        }

        #expect(sidString == "S-1-1-0")

    }


    @Test
    func `detach copies a present ACL and outlives its descriptor`() {

        let detachedAcl: WindowsRawAcl? = {
            let descriptor = Self.makeDescriptorWithDacl()
            return descriptor.dacl.detach()
        }()

        if let detachedAcl {
            #expect(detachedAcl.aceCount == 1)
            #expect(detachedAcl[0].permission.sid.string == "S-1-1-0")
        } else {
            Issue.record("A present DACL should detach into an owning copy")
        }

    }


    @Test
    func `detach returns nil for the absent and null states`() {

        var detachedAbsent = false
        if let _ = Self.makeDescriptorWithoutAcls().dacl.detach() {
            detachedAbsent = true
        }

        var detachedNull = false
        if let _ = Self.makeDescriptorWithNullDacl().dacl.detach() {
            detachedNull = true
        }

        #expect(detachedAbsent == false)
        #expect(detachedNull == false)

    }

}

#endif
