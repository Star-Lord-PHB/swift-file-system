#if !canImport(WinSDK)

import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("POSIX permissions")
    struct POSIXPermissionTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.POSIXPermissionTests {

    private func capturePermissions(at path: FilePath) throws -> FilePermissions {
        try Support.ItemMetadata.captureSecurity(at: path).permissions
    }


    private func setFoundationPermissions(
        _ permissions: FilePermissions,
        at path: FilePath
    ) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions.rawValue)],
            ofItemAtPath: path.string
        )
    }


    @Test
    func `Permission query matches stat`() throws {

        let expected = FilePermissions(rawValue: 0o6750)
        let path = try workspace.makeFile(at: "file")
        try setFoundationPermissions(expected, at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let actual = try handle.posixPermissions()
        let nativeValue = try capturePermissions(at: path)

        #expect(actual == nativeValue)

        try handle.close()

    }


    @Test
    func `Sets exact file permissions`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o6750)
        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setPosixPermissions(requestedPermissions)

        try handle.close()

        #expect(try capturePermissions(at: path) == requestedPermissions)

    }


    @Test
    func `Directory handle sets exact permissions`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o1750)
        let path = try workspace.makeDirectory(at: "directory")
        let handle = try DirectoryHandle(forDirAt: path)

        try handle.setPosixPermissions(requestedPermissions)

        try handle.close()

        #expect(try capturePermissions(at: path) == requestedPermissions)

    }

}

#endif
