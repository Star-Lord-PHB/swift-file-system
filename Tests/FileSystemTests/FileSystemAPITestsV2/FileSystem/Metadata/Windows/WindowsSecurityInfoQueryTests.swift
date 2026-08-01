#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Windows security info")
    struct WindowsSecurityInfoTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.WindowsSecurityInfoTests {

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
        secondaryPermission: WindowsAccessMask? = nil,
        inheritance: WindowsExplicitAccess.Inheritance = .noInheritance
    ) -> WindowsRawAcl {
        var entries = [
            WindowsExplicitAccess(
                permission: [fileGenericReadAccessMask, fileGenericWriteAccessMask, fileGenericExecuteAccessMask],
                inheritance: inheritance,
                trustee: .everyone
            )
        ]
        if let secondaryPermission {
            entries.append(
                WindowsExplicitAccess(
                    permission: secondaryPermission,
                    inheritance: inheritance,
                    trustee: .users
                )
            )
        }
        return WindowsRawAcl(entries: .init(entries))
    }


    private func captureSecuritySnapshot(
        at path: FilePath,
        querying members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Support.WindowsSecuritySnapshot {
        try Support.captureWindowsSecuritySnapshot(
            at: path,
            querying: members,
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `Default file query matches Win32`() throws {

        let path = try workspace.makeFile(at: "file")

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try captureSecuritySnapshot(at: path)

        Support.expectWindowsSecurity(actual, matches: expected)

    }


    @Test
    func `Default dir query matches Win32`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try captureSecuritySnapshot(at: path)

        Support.expectWindowsSecurity(actual, matches: expected)

    }


    @Test
    func `DACL-only query returns only DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        let members = .dacl as FileOperationOptions.WindowsSecurityInfoMembers

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path, querying: members)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try captureSecuritySnapshot(
            at: path,
            querying: members
        )

        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

    }


    @Test
    func `Owner-only query returns only owner`() throws {

        let path = try workspace.makeFile(at: "file")
        let members = .owner as FileOperationOptions.WindowsSecurityInfoMembers

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path, querying: members)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try captureSecuritySnapshot(
            at: path,
            querying: members
        )

        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

    }


    @Test
    func `Group-only query returns only group`() throws {

        let path = try workspace.makeFile(at: "file")
        let members = .group as FileOperationOptions.WindowsSecurityInfoMembers

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path, querying: members)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try captureSecuritySnapshot(
            at: path,
            querying: members
        )

        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

    }


    @Test
    func `Default query follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetDacl = makeWindowsTestDacl(secondaryPermission: .genericRead)
        let linkDacl = makeWindowsTestDacl(secondaryPermission: .genericWrite)
        try Support.setProtectedNativeWindowsDacl(targetDacl, at: target, followSymlink: true)
        try Support.setProtectedNativeWindowsDacl(linkDacl, at: link, followSymlink: false)

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: link)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try captureSecuritySnapshot(at: target)
        let linkSecurity = try captureSecuritySnapshot(at: link)

        Support.expectWindowsSecurity(actual, matches: expected)
        #expect(actual.dacl != linkSecurity.dacl)

    }


    @Test
    func `No-follow query returns symlink security`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetDacl = makeWindowsTestDacl(secondaryPermission: .genericRead)
        let linkDacl = makeWindowsTestDacl(secondaryPermission: .genericWrite)
        try Support.setProtectedNativeWindowsDacl(targetDacl, at: target, followSymlink: true)
        try Support.setProtectedNativeWindowsDacl(linkDacl, at: link, followSymlink: false)

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: link, followSymlink: false)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try captureSecuritySnapshot(at: link)
        let targetSecurity = try captureSecuritySnapshot(at: target)

        Support.expectWindowsSecurity(actual, matches: expected)
        #expect(actual.dacl != targetSecurity.dacl)

    }


    @Test
    func `No-follow query handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: link, followSymlink: false)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try captureSecuritySnapshot(at: link)

        Support.expectWindowsSecurity(actual, matches: expected)

    }


    @Test
    func `Default query fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            _ = try fileSystem.getSecurityInfo(forItemAt: link)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Missing security query fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            _ = try fileSystem.getSecurityInfo(forItemAt: path)
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
