#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("Explicit access array")
    struct WindowsExplicitAccessArrayTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsExplicitAccessArrayTests {

    @Test
    func `Empty array reports no entries`() {

        let entries = [] as WindowsExplicitAccessArray

        #expect(entries.count == 0)
        #expect(entries.isEmpty)
        entries.withUnsafeRawExplicitAccessBuffer { buffer in
            #expect(buffer.count == 0)
        }

    }


    @Test
    func `Array literal keeps entries in order`() {

        let entries: WindowsExplicitAccessArray = [
            .init(permission: .readData, accessMode: .grantAccess, trustee: .everyone),
            .init(permission: .writeData, accessMode: .denyAccess, trustee: .system)
        ]

        #expect(entries.count == 2)
        #expect(entries.isEmpty == false)
        #expect(entries[0].permission == .readData)
        #expect(entries[0].accessMode == .grantAccess)
        #expect(entries[0].trustee.sid == .everyone)
        #expect(entries[1].permission == .writeData)
        #expect(entries[1].accessMode == .denyAccess)
        #expect(entries[1].trustee.sid == .system)

    }


    @Test
    func `Sequence initializer keeps entries in order`() {

        let entries = WindowsExplicitAccessArray([
            .init(permission: .readData, trustee: .everyone),
            .init(permission: .writeData, trustee: .system)
        ])

        #expect(entries.count == 2)
        #expect(entries[0].trustee.sid == .everyone)
        #expect(entries[1].trustee.sid == .system)

    }


    @Test
    func `append adds an entry at the end`() {

        var entries: WindowsExplicitAccessArray = [
            .init(permission: .readData, trustee: .everyone)
        ]

        entries.append(.init(permission: .delete, trustee: .administrators))

        #expect(entries.count == 2)
        #expect(entries[0].trustee.sid == .everyone)
        #expect(entries[1].permission == .delete)
        #expect(entries[1].trustee.sid == .administrators)

    }


    @Test
    func `Appending an array or a sequence keeps entries in order`() {

        var entries: WindowsExplicitAccessArray = [
            .init(permission: .readData, trustee: .everyone)
        ]
        let otherEntries: WindowsExplicitAccessArray = [
            .init(permission: .writeData, trustee: .system)
        ]

        // The overload taking another WindowsExplicitAccessArray.
        entries.append(contentsOf: otherEntries)

        // The overload taking any Sequence of entries.
        entries.append(contentsOf: [
            WindowsExplicitAccess(permission: .delete, trustee: .administrators)
        ] as [WindowsExplicitAccess])

        #expect(entries.count == 3)
        #expect(entries[0].trustee.sid == .everyone)
        #expect(entries[1].trustee.sid == .system)
        #expect(entries[2].trustee.sid == .administrators)

    }


    @Test
    func `Subscript setter replaces the entry and its trustee`() {

        var entries: WindowsExplicitAccessArray = [
            .init(permission: .readData, trustee: .everyone)
        ]

        entries[0] = .init(
            permission: .delete,
            accessMode: .denyAccess,
            inheritance: .subFiles,
            trustee: .administrators
        )

        #expect(entries[0].permission == .delete)
        #expect(entries[0].accessMode == .denyAccess)
        #expect(entries[0].inheritance == .subFiles)
        #expect(entries[0].trustee.sid == .administrators)

        entries.withUnsafeRawExplicitAccessBuffer { buffer in
            let trusteeSid = UnsafeMutableRawPointer(buffer[0].Trustee.ptstrName)

            #expect(IsValidSid(trusteeSid))
            WindowsSid.administrators.withUnsafePSid { administratorsSid in
                #expect(EqualSid(trusteeSid, administratorsSid))
            }
        }

    }


    @Test
    func `Raw buffer exposes every entry with a live trustee`() throws {

        var entries = [] as WindowsExplicitAccessArray

        // The array becomes the only owner of this SID, so an array that stored the native
        // entry without retaining its trustee would leave the buffer dangling.
        entries.append(
            .init(
                permission: .readData,
                trustee: .init(sid: try #require(WindowsSid(string: "S-1-5-32-544")), type: .alias)
            )
        )
        entries.append(.init(permission: .writeData, accessMode: .denyAccess, trustee: .system))

        entries.withUnsafeRawExplicitAccessBuffer { buffer in
            #expect(buffer.count == 2)
            #expect(buffer[0].grfAccessPermissions == WindowsAccessMask.readData.rawValue)
            #expect(buffer[0].Trustee.TrusteeType == TRUSTEE_IS_ALIAS)
            #expect(buffer[1].grfAccessPermissions == WindowsAccessMask.writeData.rawValue)
            #expect(buffer[1].grfAccessMode == DENY_ACCESS)

            let trusteeSid = UnsafeMutableRawPointer(buffer[0].Trustee.ptstrName)

            #expect(IsValidSid(trusteeSid))
            WindowsSid.administrators.withUnsafePSid { administratorsSid in
                #expect(EqualSid(trusteeSid, administratorsSid))
            }
        }

    }

}

#endif
