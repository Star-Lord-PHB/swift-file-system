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
// `WindowsRawAclState` is `~Escapable`, so a bare `#expect(state.isAbsent)` fails to compile:
// the macro rewrites it into a member access that requires `Escapable`. Comparing the property
// instead keeps the macro on its binary-operation path.
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

        #expect(state.case == .absent)
        #expect(state.isAbsent == true)
        #expect(state.isNull == false)
        #expect(state.defaulted == nil)

    }


    @Test
    func `Null DACL is present without an ACL`() {

        let descriptor = Self.makeDescriptorWithNullDacl()
        let state = descriptor.dacl

        #expect(state.case == .null)
        #expect(state.isAbsent == false)
        #expect(state.isNull == true)
        #expect(state.defaulted == false)

    }


    @Test
    func `Present DACL exposes its ACEs`() {

        let descriptor = Self.makeDescriptorWithDacl()
        let state = descriptor.dacl

        #expect(state.case == .present)
        #expect(state.isAbsent == false)
        #expect(state.isNull == false)
        #expect(state.defaulted == false)

        // Optional-chaining a subscript into the borrowed ACL crashes the Windows 6.2
        // MoveOnlyChecker, so the ACL is bound before its ACEs are read.
        if let acl = state.value {
            #expect(acl.aceCount == 1)
            #expect(acl[0].permission.sid.string == "S-1-1-0")
        } else {
            Issue.record("A present DACL should expose its ACL")
        }

    }


    @Test
    func `detach copies a present ACL and outlives its descriptor`() {

        let detachedAcl: WindowsRawAcl? = {
            let descriptor = Self.makeDescriptorWithDacl()
            return descriptor.dacl.detach()
        }()

        // `WindowsRawAcl` is `~Copyable`, so the macro cannot optional-chain into it here
        // without consuming it.
        if let detachedAcl {
            #expect(detachedAcl.aceCount == 1)
            #expect(detachedAcl[0].permission.sid.string == "S-1-1-0")
        } else {
            Issue.record("A present DACL should detach into an owning copy")
        }

    }


    @Test
    func `detach returns nil for the absent and null states`() {

        #expect((Self.makeDescriptorWithoutAcls().dacl.detach() == nil) == true)
        #expect((Self.makeDescriptorWithNullDacl().dacl.detach() == nil) == true)

    }

}

#endif
