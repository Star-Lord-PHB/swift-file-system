#if !canImport(WinSDK)

import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.PlatformIdentityTests {

    @Suite("POSIX")
    struct POSIXIdentityTests {}

}



extension PlatformTypesAPITests.PlatformIdentityTests.POSIXIdentityTests {

    // NOTE: a POSIX identity is a bare numeric id, which carries no namespace of its own,
    // so the same number can name both a user and a group and equality has to compare the
    // kind as well. A Windows identity is a SID, which is already unique across kinds, and
    // equality there deliberately ignores the kind; see the Windows platform identity suite.

    @Test
    func `Same raw id and kind compare equal`() {

        let identity = PlatformIdentity(rawId: 501, platformKind: .user)
        let sameIdentity = PlatformIdentity(rawId: 501, platformKind: .user)

        #expect(identity == sameIdentity)

    }


    @Test
    func `Identity equality includes the platform kind`() {

        let user = PlatformIdentity(rawId: 501, platformKind: .user)
        let group = PlatformIdentity(rawId: 501, platformKind: .group)

        #expect(user != group)

    }


    @Test
    func `Different raw ids compare unequal`() {

        let identity = PlatformIdentity(rawId: 501, platformKind: .user)
        let otherIdentity = PlatformIdentity(rawId: 502, platformKind: .user)

        #expect(identity != otherIdentity)

    }

}

#endif
