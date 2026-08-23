#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("Explicit access")
    struct WindowsExplicitAccessTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsExplicitAccessTests {

    @Test
    func `Initializer maps every native field`() {

        let permission: WindowsAccessMask = [.readData, .writeData]
        let entry = WindowsExplicitAccess(
            permission: permission,
            accessMode: .denyAccess,
            inheritance: .allSubItems,
            trustee: .administrators
        )

        entry.withUnsafeRawExplicitAccess { nativeEntry in
            #expect(nativeEntry.grfAccessPermissions == permission.rawValue)
            #expect(nativeEntry.grfAccessMode == DENY_ACCESS)
            #expect(nativeEntry.grfInheritance == DWORD(SUB_CONTAINERS_AND_OBJECTS_INHERIT))
            #expect(nativeEntry.Trustee.TrusteeForm == TRUSTEE_IS_SID)
            #expect(nativeEntry.Trustee.TrusteeType == TRUSTEE_IS_GROUP)
            #expect(nativeEntry.Trustee.MultipleTrusteeOperation == NO_MULTIPLE_TRUSTEE)
            #expect(nativeEntry.Trustee.pMultipleTrustee == nil)

            let trusteeSid = UnsafeMutableRawPointer(nativeEntry.Trustee.ptstrName)
            WindowsSid.administrators.withUnsafePSid { administratorsSid in
                #expect(EqualSid(trusteeSid, administratorsSid))
            }
        }

    }


    @Test
    func `Accessors round trip through the setters`() {

        var entry = WindowsExplicitAccess(permission: .readData, trustee: .everyone)

        #expect(entry.permission == .readData)
        #expect(entry.accessMode == .grantAccess)
        #expect(entry.inheritance == .noInheritance)
        #expect(entry.trustee.sid == .everyone)
        #expect(entry.trustee.type == .wellKnownGroup)

        entry.permission = [.writeData, .delete]
        entry.accessMode = .denyAccess
        entry.inheritance = .subFiles
        entry.trustee = .system

        #expect(entry.permission == [.writeData, .delete])
        #expect(entry.accessMode == .denyAccess)
        #expect(entry.inheritance == .subFiles)
        #expect(entry.trustee.sid == .system)
        #expect(entry.trustee.type == .user)

    }


    @Test
    func `Trustee setter keeps the new SID alive`() throws {

        var entry = WindowsExplicitAccess(permission: .readData, trustee: .everyone)

        // The entry becomes the only owner of this SID, so a setter that stored the raw
        // pointer without retaining it would leave the native trustee dangling.
        entry.trustee = .init(sid: try #require(WindowsSid(string: "S-1-5-32-544")), type: .alias)

        entry.withUnsafeRawExplicitAccess { nativeEntry in
            let trusteeSid = UnsafeMutableRawPointer(nativeEntry.Trustee.ptstrName)

            #expect(IsValidSid(trusteeSid))
            #expect(nativeEntry.Trustee.TrusteeType == TRUSTEE_IS_ALIAS)
            WindowsSid.administrators.withUnsafePSid { administratorsSid in
                #expect(EqualSid(trusteeSid, administratorsSid))
            }
        }

    }


    @Test(
        arguments: [
            (.notUsed, NOT_USED_ACCESS),
            (.grantAccess, GRANT_ACCESS),
            (.setAccess, SET_ACCESS),
            (.denyAccess, DENY_ACCESS),
            (.revokeAccess, REVOKE_ACCESS),
            (.setAuditSuccess, SET_AUDIT_SUCCESS),
            (.setAuditFailure, SET_AUDIT_FAILURE)
        ] as [(WindowsExplicitAccess.AccessMode, ACCESS_MODE)]
    )
    func `Access modes map to native access modes`(
        _ accessMode: WindowsExplicitAccess.AccessMode,
        _ nativeAccessMode: ACCESS_MODE
    ) {

        #expect(accessMode.rawAccessMode == nativeAccessMode)
        #expect(WindowsExplicitAccess.AccessMode(rawValue: nativeAccessMode.rawValue) == accessMode)

    }


    @Test(
        arguments: [
            (.unknown, TRUSTEE_IS_UNKNOWN),
            (.user, TRUSTEE_IS_USER),
            (.group, TRUSTEE_IS_GROUP),
            (.domain, TRUSTEE_IS_DOMAIN),
            (.alias, TRUSTEE_IS_ALIAS),
            (.wellKnownGroup, TRUSTEE_IS_WELL_KNOWN_GROUP),
            (.deleted, TRUSTEE_IS_DELETED),
            (.invalid, TRUSTEE_IS_INVALID),
            (.computer, TRUSTEE_IS_COMPUTER)
        ] as [(WindowsExplicitAccess.TrusteeType, TRUSTEE_TYPE)]
    )
    func `Trustee types map to native trustee types`(
        _ trusteeType: WindowsExplicitAccess.TrusteeType,
        _ nativeTrusteeType: TRUSTEE_TYPE
    ) {

        #expect(trusteeType.rawTrusteeType == nativeTrusteeType)
        #expect(WindowsExplicitAccess.TrusteeType(rawValue: nativeTrusteeType.rawValue) == trusteeType)

    }


    @Test(
        arguments: [
            (.noInheritance, DWORD(NO_INHERITANCE)),
            (.subFiles, DWORD(SUB_OBJECTS_ONLY_INHERIT)),
            (.subContainers, DWORD(SUB_CONTAINERS_ONLY_INHERIT)),
            (.noPropagate, DWORD(INHERIT_NO_PROPAGATE)),
            (.inheritOnly, DWORD(INHERIT_ONLY)),
            (.allSubItems, DWORD(SUB_CONTAINERS_AND_OBJECTS_INHERIT))
        ] as [(WindowsExplicitAccess.Inheritance, DWORD)]
    )
    func `Inheritance flags map to native flags`(
        _ inheritance: WindowsExplicitAccess.Inheritance,
        _ rawValue: DWORD
    ) {

        #expect(inheritance.rawValue == rawValue)

    }


    @Test(
        arguments: [
            (.everyone, "S-1-1-0", .wellKnownGroup),
            (.creatorOwner, "S-1-3-0", .wellKnownGroup),
            (.creatorGroup, "S-1-3-1", .wellKnownGroup),
            (.anonymous, "S-1-5-7", .wellKnownGroup),
            (.authenticatedUsers, "S-1-5-11", .wellKnownGroup),
            (.system, "S-1-5-18", .user),
            (.localService, "S-1-5-19", .wellKnownGroup),
            (.networkService, "S-1-5-20", .wellKnownGroup),
            (.administrators, "S-1-5-32-544", .group),
            (.users, "S-1-5-32-545", .wellKnownGroup)
        ] as [(WindowsExplicitAccess.RawTrustee, String, WindowsExplicitAccess.TrusteeType)]
    )
    func `Well-known trustees carry their SID and type`(
        _ trustee: WindowsExplicitAccess.RawTrustee,
        _ sidString: String,
        _ trusteeType: WindowsExplicitAccess.TrusteeType
    ) {

        #expect(trustee.sid.string == sidString)
        #expect(trustee.type == trusteeType)

    }

}

#endif
