#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Windows security info")
    struct WindowsSecurityInfoTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.WindowsSecurityInfoTests {

    var fileGenericReadAccessMask: WindowsAccessMask {
        .init(rawValue: FILE_GENERIC_READ)
    }

    var fileGenericWriteAccessMask: WindowsAccessMask {
        .init(rawValue: FILE_GENERIC_WRITE)
    }

    var fileGenericExecuteAccessMask: WindowsAccessMask {
        .init(rawValue: FILE_GENERIC_EXECUTE)
    }


    func makeWindowsTestDacl(
        secondaryPermission: WindowsAccessMask? = nil
    ) -> WindowsRawAcl {
        var entries = [
            WindowsExplicitAccess(
                permission: [
                    fileGenericReadAccessMask,
                    fileGenericWriteAccessMask,
                    fileGenericExecuteAccessMask,
                ],
                inheritance: .noInheritance,
                trustee: .everyone
            )
        ]
        if let secondaryPermission {
            entries.append(
                WindowsExplicitAccess(
                    permission: secondaryPermission,
                    inheritance: .noInheritance,
                    trustee: .users
                )
            )
        }
        return WindowsRawAcl(entries: .init(entries))
    }


    private func captureSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Support.ItemMetadata.Security {
        try Support.ItemMetadata.captureSecurity(
            at: path,
            sourceLocation: sourceLocation
        )
    }

}



extension FileHandleAPITests.MetadataTests.WindowsSecurityInfoTests {

    @Test
    func `Default query matches Win32`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let descriptor = try handle.securityInfo()
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecuritySnapshot(at: path)

        Support.expectWindowsSecurity(actual, matches: expected)

        try handle.close()

    }


    @Test
    func `DACL-only query returns only DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        let members = .dacl as FileOperationOptions.WindowsSecurityInfoMembers
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let descriptor = try handle.securityInfo(members)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecuritySnapshot(
            at: path,
            querying: members
        )

        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

        try handle.close()

    }

}



extension FileHandleAPITests.MetadataTests.WindowsSecurityInfoTests {

    // NOTE: Handles are opened before the restrictive protected DACL is installed;
    // security access rights are checked at open time, so an already-open handle may
    // keep updating the security info afterwards.

    @Test
    func `Replacing DACL preserves ownership`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        try Support.setProtectedNativeWindowsDacl(
            makeWindowsTestDacl(),
            at: path,
            followSymlink: true
        )
        let securityBeforeSet = try captureSecurity(at: path)
        let replacementDacl = makeWindowsTestDacl(secondaryPermission: fileGenericReadAccessMask)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try handle.setSecurityInfo(dacl: .replace(replacementDacl))

        try handle.close()

        let securityAfterSet = try captureSecurity(at: path)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        Support.expectWindowsAcl(securityAfterSet.permissions.dacl, matches: expectedDacl)

    }


    @Test
    func `Removing DACL installs null DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        try Support.setProtectedNativeWindowsDacl(
            makeWindowsTestDacl(),
            at: path,
            followSymlink: true
        )
        let securityBeforeSet = try captureSecurity(at: path)

        try handle.setSecurityInfo(dacl: .remove)

        try handle.close()

        let securityAfterSet = try captureSecurity(at: path)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        #expect(securityAfterSet.permissions.dacl.state == .null)
        #expect(securityAfterSet.permissions.dacl.aces.isEmpty)

    }


    @Test
    func `No-change update preserves security`() throws {

        let path = try workspace.makeFile(at: "file")
        let securityBeforeSet = try captureSecurity(at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setSecurityInfo()

        try handle.close()

        let securityAfterSet = try captureSecurity(at: path)
        Support.expectWindowsSecurity(securityAfterSet, matches: securityBeforeSet)

    }

}

#endif
