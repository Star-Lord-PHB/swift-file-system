#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests {

    /// The Windows-only shells plus the security-descriptor value flow that is unique to the
    /// async surface: the `Sendable` view crossing the `@concurrent` boundary (via the four
    /// borrowing convenience overloads) and the `sending` owned descriptor coming back from
    /// `getSecurityInfo`.
    @Suite("Windows security forwarding")
    struct WindowsSecurityForwardingTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let fileSystem = FileSystem()
        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.WindowsSecurityForwardingTests {

    private static func makeSampleTargetDacl() -> WindowsRawAcl {
        .init(entries: [
            .init(
                permission: .init(
                    rawValue: FILE_GENERIC_READ | FILE_GENERIC_WRITE | FILE_GENERIC_EXECUTE
                ),
                trustee: .everyone
            )
        ])
    }


    private static func makeSampleTargetSecurityDescriptor() -> WindowsAbsoluteSecurityDescriptor {
        return WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: .acl(makeSampleTargetDacl())
        )
    }


    private func expectSampleTargetSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let security = try Support.ItemMetadata.captureSecurity(
            at: path,
            sourceLocation: sourceLocation
        )
        let expectedDacl = try Support.parseWindowsRawAcl(
            Self.makeSampleTargetDacl(),
            sourceLocation: sourceLocation
        )

        #expect(
            security.permissions.isProtected,
            sourceLocation: sourceLocation
        )
        Support.expectWindowsAcl(
            security.permissions.dacl,
            matches: expectedDacl,
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `createFile forwards an absolute security descriptor`() async throws {

        let path = workspace.path("file")
        let security = Self.makeSampleTargetSecurityDescriptor()

        try await asyncFileSystem.createFile(at: path, permissions: security)

        try expectSampleTargetSecurity(at: path)

    }


    @Test
    func `createDirectory forwards an absolute security descriptor`() async throws {

        let path = workspace.path("directory")
        let security = Self.makeSampleTargetSecurityDescriptor()

        try await asyncFileSystem.createDirectory(at: path, permissions: security)

        try expectSampleTargetSecurity(at: path)

    }


    @Test
    func `createFile forwards a self-relative security descriptor`() async throws {

        let path = workspace.path("file")
        let security = Self.makeSampleTargetSecurityDescriptor().makeSelfRelative()

        try await asyncFileSystem.createFile(at: path, permissions: security)

        try expectSampleTargetSecurity(at: path)

    }


    @Test
    func `createDirectory forwards a self-relative security descriptor`() async throws {

        let path = workspace.path("directory")
        let security = Self.makeSampleTargetSecurityDescriptor().makeSelfRelative()

        try await asyncFileSystem.createDirectory(at: path, permissions: security)

        try expectSampleTargetSecurity(at: path)

    }


    @Test
    func `getSecurityInfo matches Win32`() async throws {

        let path = try workspace.makeFile(at: "file")

        let descriptor = try await asyncFileSystem.getSecurityInfo(forItemAt: path)

        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecuritySnapshot(at: path)
        Support.expectWindowsSecurity(actual, matches: expected)

    }


    @Test
    func `getSecurityInfo forwards the queried members`() async throws {

        let path = try workspace.makeFile(at: "file")
        let members = .owner as FileOperationOptions.WindowsSecurityInfoMembers

        let descriptor = try await asyncFileSystem.getSecurityInfo(forItemAt: path, querying: members)

        // expectWindowsSecurity asserts the members outside `comparing:` are nil, so a
        // dropped `querying` forward (falling back to allExceptSacl) fails here.
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecuritySnapshot(at: path, querying: members)
        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

    }


    @Test
    func `setSecurityInfo forwards a DACL replacement`() async throws {

        let path = try workspace.makeFile(at: "file")
        try Support.setProtectedNativeWindowsDacl(
            .init(entries: [
                .init(permission: .genericRead, trustee: .users)
            ]),
            at: path,
            followSymlink: false
        )
        let expectedDacl = try Support.parseWindowsRawAcl(Self.makeSampleTargetDacl())

        try await asyncFileSystem.setSecurityInfo(
            forItemAt: path,
            dacl: .replace(Self.makeSampleTargetDacl())
        )

        let securityAfterSet = try Support.ItemMetadata.captureSecurity(at: path)
        Support.expectWindowsAcl(
            securityAfterSet.permissions.dacl,
            matches: expectedDacl
        )

    }


    @Test
    func `Pre-cancelled security-descriptor createFile reports cancellation`() async throws {

        let path = workspace.path("file")
        let asyncFileSystem = self.asyncFileSystem

        await AsyncFileSystemAPITests.expectPreCancelled {
            let security = Self.makeSampleTargetSecurityDescriptor()
            return try await asyncFileSystem.createFile(at: path, permissions: security)
        }

        try Support.expectItemNotExistNoFollow(at: path)

    }


    @Test
    func `Pre-cancelled security-descriptor createDirectory reports cancellation`() async throws {

        let path = workspace.path("directory")
        let asyncFileSystem = self.asyncFileSystem

        await AsyncFileSystemAPITests.expectPreCancelled {
            let security = Self.makeSampleTargetSecurityDescriptor()
            return try await asyncFileSystem.createDirectory(at: path, permissions: security)
        }

        try Support.expectItemNotExistNoFollow(at: path)

    }


    @Test
    func `Pre-cancelled getSecurityInfo reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await AsyncFileSystemAPITests.expectPreCancelled {
            _ = try await asyncFileSystem.getSecurityInfo(forItemAt: path)
        }

    }


    @Test
    func `Pre-cancelled setSecurityInfo reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await AsyncFileSystemAPITests.expectPreCancelled {
            try await asyncFileSystem.setSecurityInfo(forItemAt: path)
        }

    }

}

#endif
