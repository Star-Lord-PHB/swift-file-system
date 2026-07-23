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

    @Test
    func `Default file query matches Win32`() throws {

        let path = try workspace.makeFile(at: "file")

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecurity(at: path, followSymlink: true)

        Support.expectWindowsSecurity(actual, matches: expected)

    }


    @Test
    func `Default dir query matches Win32`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecurity(at: path, followSymlink: true)

        Support.expectWindowsSecurity(actual, matches: expected)

    }


    @Test
    func `DACL-only query returns only DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        let members = .dacl as FileOperationOptions.WindowsSecurityInfoMembers

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path, querying: members)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecurity(
            at: path,
            querying: members,
            followSymlink: true
        )

        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

    }


    @Test
    func `Owner-only query returns only owner`() throws {

        let path = try workspace.makeFile(at: "file")
        let members = .owner as FileOperationOptions.WindowsSecurityInfoMembers

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path, querying: members)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecurity(
            at: path,
            querying: members,
            followSymlink: true
        )

        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

    }


    @Test
    func `Group-only query returns only group`() throws {

        let path = try workspace.makeFile(at: "file")
        let members = .group as FileOperationOptions.WindowsSecurityInfoMembers

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: path, querying: members)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecurity(
            at: path,
            querying: members,
            followSymlink: true
        )

        Support.expectWindowsSecurity(actual, matches: expected, comparing: members)

    }


    @Test
    func `Default query follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericRead)
        let linkDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericWrite)
        try Support.setProtectedNativeWindowsDacl(targetDacl, at: target, followSymlink: true)
        try Support.setProtectedNativeWindowsDacl(linkDacl, at: link, followSymlink: false)

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: link)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecurity(at: target, followSymlink: true)
        let linkSecurity = try Support.captureWindowsSecurity(at: link, followSymlink: false)

        Support.expectWindowsSecurity(actual, matches: expected)
        #expect(actual.dacl != linkSecurity.dacl)

    }


    @Test
    func `No-follow query returns symlink security`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericRead)
        let linkDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericWrite)
        try Support.setProtectedNativeWindowsDacl(targetDacl, at: target, followSymlink: true)
        try Support.setProtectedNativeWindowsDacl(linkDacl, at: link, followSymlink: false)

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: link, followSymlink: false)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecurity(at: link, followSymlink: false)
        let targetSecurity = try Support.captureWindowsSecurity(at: target, followSymlink: true)

        Support.expectWindowsSecurity(actual, matches: expected)
        #expect(actual.dacl != targetSecurity.dacl)

    }


    @Test
    func `No-follow query handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let descriptor = try fileSystem.getSecurityInfo(forItemAt: link, followSymlink: false)
        let actual = try Support.parseWindowsSecurityDescriptor(descriptor)
        let expected = try Support.captureWindowsSecurity(at: link, followSymlink: false)

        Support.expectWindowsSecurity(actual, matches: expected)

    }


    @Test
    func `Default query fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getSecurityInfo(forItemAt: link)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Missing security query fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getSecurityInfo(forItemAt: path)
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
