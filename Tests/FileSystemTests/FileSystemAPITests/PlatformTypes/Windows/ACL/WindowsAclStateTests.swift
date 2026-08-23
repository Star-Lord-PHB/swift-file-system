#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("ACL state")
    struct WindowsAclStateTests {}

}



// `WindowsRawAclState` is `~Copyable`, so a bare `#expect(state.isAbsent)` would make the
// macro capture the state itself. Comparing the property instead keeps the macro on its
// binary-operation path, mirroring the ACL state view suite.
extension PlatformTypesAPITests.WindowsSecurityTests.WindowsAclStateTests {

    private static func makeSampleAcl() -> WindowsRawAcl {
        .init(entries: [.init(permission: .readData, trustee: .everyone)])
    }


    private static func expectSingleEveryoneAce(
        _ state: borrowing WindowsRawAclState,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        if let acl = state.value {
            #expect(acl.aceCount == 1, sourceLocation: sourceLocation)
            #expect(acl[0].permission.sid.string == "S-1-1-0", sourceLocation: sourceLocation)
        } else {
            Issue.record("The state should hold an ACL", sourceLocation: sourceLocation)
        }
    }


    @Test
    func `Absent and null states have no ACL`() {

        let absent = WindowsRawAclState.absent

        #expect(absent.case == .absent)
        #expect(absent.isAbsent == true)
        #expect(absent.isNull == false)
        #expect((absent.value == nil) == true)

        let null = WindowsRawAclState.null

        #expect(null.case == .null)
        #expect(null.isAbsent == false)
        #expect(null.isNull == true)
        #expect((null.value == nil) == true)

    }


    @Test
    func `Present state exposes its ACL`() {

        let state = WindowsRawAclState.acl(Self.makeSampleAcl())

        #expect(state.case == .acl)
        #expect(state.isAbsent == false)
        #expect(state.isNull == false)
        Self.expectSingleEveryoneAce(state)

    }


    @Test
    func `addEntries turns the absent and null states into a present ACL`() {

        var fromAbsent = WindowsRawAclState.absent
        fromAbsent.addEntries([.init(permission: .readData, trustee: .everyone)])

        #expect(fromAbsent.case == .acl)
        Self.expectSingleEveryoneAce(fromAbsent)

        var fromNull = WindowsRawAclState.null
        fromNull.addEntries([.init(permission: .readData, trustee: .everyone)])

        #expect(fromNull.case == .acl)
        Self.expectSingleEveryoneAce(fromNull)

    }


    @Test
    func `addEntries merges into a present state`() {

        var state = WindowsRawAclState.acl(Self.makeSampleAcl())
        state.addEntries([.init(permission: .delete, trustee: .administrators)])

        #expect(state.case == .acl)
        #expect(state.value?.aceCount == 2)

        let sidStrings = state.value?.map { $0.permission.sid.string }

        #expect(sidStrings?.contains("S-1-1-0") == true)
        #expect(sidStrings?.contains("S-1-5-32-544") == true)

    }


    @Test
    func `take returns the ACL and installs the requested state`() {

        var state = WindowsRawAclState.acl(Self.makeSampleAcl())
        let taken = state.take(leaving: .null)

        #expect(state.isNull == true)

        // `WindowsRawAcl` is `~Copyable`, so the macro cannot optional-chain into it here
        // without consuming it.
        if let taken {
            #expect(taken.aceCount == 1)
            #expect(taken[0].permission.sid.string == "S-1-1-0")
        } else {
            Issue.record("A present state should hand its ACL over")
        }

    }


    @Test
    func `take from an empty state still installs the requested state`() {

        var state = WindowsRawAclState.absent
        let taken = state.take(leaving: .acl(Self.makeSampleAcl()))

        #expect((taken == nil) == true)
        #expect(state.case == .acl)
        Self.expectSingleEveryoneAce(state)

    }

}

#endif
