#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("Windows security forwarding")
    struct WindowsSecurityTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The Windows security shells and the creation-time parameter of `setFileTimes` are
// conditional source. Handles are opened before a restrictive protected DACL is installed:
// security access rights are checked at open time, so the open handle keeps updating the
// security info afterwards.
extension AsyncFileHandleAPITests.MetadataTests.WindowsSecurityTests {

    private static func makeSampleDacl() -> WindowsRawAcl {
        .init(entries: [
            .init(
                permission: .init(rawValue: FILE_GENERIC_READ | FILE_GENERIC_WRITE | FILE_GENERIC_EXECUTE),
                trustee: .everyone
            )
        ])
    }


    @Test
    func `securityInfo matches Win32`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        let descriptor = try await handle.securityInfo()

        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecuritySnapshot(at: path)
        Support.expectWindowsSecurity(actual, matches: expected)

        try await handle.close()

    }


    @Test
    func `securityInfo forwards the queried members`() async throws {

        let path = try workspace.makeFile(at: "file")
        let members = .owner as FileOperationOptions.WindowsSecurityInfoMembers
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        let descriptor = try await handle.securityInfo(members)

        // expectWindowsSecurity asserts the members outside `comparing:` are nil, so a
        // dropped members forward (falling back to allExceptSacl) fails here.
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecuritySnapshot(at: path, querying: members)
        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

        try await handle.close()

    }


    @Test
    func `setSecurityInfo forwards a DACL replacement`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        try Support.setProtectedNativeWindowsDacl(
            .init(entries: [
                .init(permission: .genericRead, trustee: .users)
            ]),
            at: path,
            followSymlink: true
        )
        let securityBeforeSet = try Support.ItemMetadata.captureSecurity(at: path)
        let expectedDacl = try Support.parseWindowsRawAcl(Self.makeSampleDacl())

        try await handle.setSecurityInfo(dacl: .replace(Self.makeSampleDacl()))

        try await handle.close()

        let securityAfterSet = try Support.ItemMetadata.captureSecurity(at: path)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        Support.expectWindowsAcl(securityAfterSet.permissions.dacl, matches: expectedDacl)

    }


    @Test
    func `setFileTimes forwards the creation time`() async throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)
        let creationTimeBeforeSet = try #require(timesBeforeSet.creation)
        let requestedCreationTime = creationTimeBeforeSet
            .adding(seconds: -7_200)
            .fileTimeSpec
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        try await handle.setFileTimes(creation: requestedCreationTime)

        try await handle.close()

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        Support.expectTimestampEquals(
            timesAfterSet.creation,
            .init(fileTimeSpec: requestedCreationTime),
            comment: "Creation time"
        )
        Support.expectTimestampEquals(
            timesAfterSet.modification,
            timesBeforeSet.modification,
            comment: "Modification time"
        )

    }


    @Test
    func `Pre-cancelled securityInfo reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            _ = try await handle.securityInfo()
        }

    }


    @Test
    func `Pre-cancelled setSecurityInfo reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.setSecurityInfo(dacl: .remove)
        }

    }

}

#endif
