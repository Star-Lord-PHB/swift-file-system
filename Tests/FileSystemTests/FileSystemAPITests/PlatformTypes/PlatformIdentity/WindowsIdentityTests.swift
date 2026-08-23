#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.PlatformIdentityTests {

    @Suite("Windows")
    struct WindowsIdentityTests {}

}



extension PlatformTypesAPITests.PlatformIdentityTests.WindowsIdentityTests {

    // NOTE: a SID already identifies an account across kinds, so equality compares the SID
    // alone and an identity built with a guessed or stale kind still matches the account it
    // names. POSIX ids are only meaningful together with their namespace, so equality there
    // also compares the kind; see the POSIX platform identity suite.

    @Test
    func `Same SID compares equal regardless of the platform kind`() {

        let identity = PlatformIdentity(rawId: .everyone, platformKind: .wellknownGroup)
        let otherKindIdentity = PlatformIdentity(rawId: .everyone, platformKind: .user)

        #expect(identity == otherKindIdentity)
        #expect(identity.hashValue == otherKindIdentity.hashValue)

    }


    @Test
    func `Different SIDs compare unequal`() {

        let everyone = PlatformIdentity(rawId: .everyone, platformKind: .wellknownGroup)
        let system = PlatformIdentity(rawId: .system, platformKind: .wellknownGroup)

        #expect(everyone != system)

    }


    @Test(
        arguments: [
            (.user, SidTypeUser),
            (.group, SidTypeGroup),
            (.domain, SidTypeDomain),
            (.alias, SidTypeAlias),
            (.wellknownGroup, SidTypeWellKnownGroup),
            (.deletedAccount, SidTypeDeletedAccount),
            (.invalid, SidTypeInvalid),
            (.unknown, SidTypeUnknown),
            (.computer, SidTypeComputer),
            (.label, SidTypeLabel),
            (.logonSession, SidTypeLogonSession)
        ] as [(PlatformIdentity.PlatformKind, SID_NAME_USE)]
    )
    func `Platform kinds round trip through the native SID name use`(
        _ kind: PlatformIdentity.PlatformKind,
        _ nativeUse: SID_NAME_USE
    ) {

        #expect(kind.rawValue == nativeUse)
        #expect(PlatformIdentity.PlatformKind(rawValue: nativeUse) == kind)

    }


    @Test
    func `Unrecognized native SID name use maps to unknown`() {

        #expect(PlatformIdentity.PlatformKind(rawValue: SID_NAME_USE(rawValue: 9999)) == .unknown)

    }

}

#endif
