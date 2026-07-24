#if !canImport(WinSDK)

import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("POSIX permissions")
    struct POSIXPermissionTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.POSIXPermissionTests {

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
    func `File permission query matches stat`() throws {

        let expected = FilePermissions(rawValue: 0o6750)
        let path = try workspace.makeFile(at: "file")
        try setFoundationPermissions(expected, at: path)

        let actual = try fileSystem.getPosixPermissions(forItemAt: path)
        let nativeValue = try capturePermissions(at: path)

        #expect(actual == nativeValue)

    }


    @Test
    func `Dir permission query matches stat`() throws {

        let expected = FilePermissions(rawValue: 0o1750)
        let path = try workspace.makeDirectory(at: "directory")
        try setFoundationPermissions(expected, at: path)

        let actual = try fileSystem.getPosixPermissions(forItemAt: path)
        let nativeValue = try capturePermissions(at: path)

        #expect(actual == nativeValue)

    }


    @Test
    func `Permission query follows symlinks by default`() throws {

        let target = try workspace.makeFile(at: "target")
        try setFoundationPermissions(.init(rawValue: 0o640), at: target)
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let actual = try fileSystem.getPosixPermissions(forItemAt: link)
        let expected = try capturePermissions(at: target)

        #expect(actual == expected)

    }


    @Test
    func `No-follow permission query returns symlink permissions`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let actual = try fileSystem.getPosixPermissions(
            forItemAt: link,
            followSymlink: false
        )
        let expected = try capturePermissions(at: link)

        #expect(actual == expected)

    }


    @Test
    func `No-follow permission query handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let actual = try fileSystem.getPosixPermissions(
            forItemAt: link,
            followSymlink: false
        )
        let expected = try capturePermissions(at: link)

        #expect(actual == expected)

    }


    @Test
    func `Default permission query fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getPosixPermissions(forItemAt: link)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Missing permission query fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getPosixPermissions(forItemAt: path)
        }

        #expect(error?.kind == .notFound)

    }

}



extension FileSystemAPITests.MetadataTests.POSIXPermissionTests {

    @Test
    func `Sets exact file permissions`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o6750)
        let path = try workspace.makeFile(at: "file")

        try fileSystem.setPosixPermissions(forItemAt: path, permissions: requestedPermissions)

        #expect(try capturePermissions(at: path) == requestedPermissions)

    }


    @Test
    func `Sets exact dir permissions`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o1750)
        let path = try workspace.makeDirectory(at: "directory")

        try fileSystem.setPosixPermissions(forItemAt: path, permissions: requestedPermissions)

        #expect(try capturePermissions(at: path) == requestedPermissions)

    }


    @Test
    func `Default permission set follows symlink`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o640)
        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let linkPermissionsBeforeSet = try capturePermissions(at: link)

        try fileSystem.setPosixPermissions(forItemAt: link, permissions: requestedPermissions)

        #expect(try capturePermissions(at: target) == requestedPermissions)
        #expect(try capturePermissions(at: link) == linkPermissionsBeforeSet)

    }


    @Test
    func `No-follow permission set changes symlink only when supported`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o750)
        let target = try workspace.makeFile(at: "target")
        try setFoundationPermissions(.init(rawValue: 0o640), at: target)
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetPermissionsBeforeSet = try capturePermissions(at: target)

        do {
            try fileSystem.setPosixPermissions(
                forItemAt: link,
                permissions: requestedPermissions,
                followSymlink: false
            )
            #expect(try capturePermissions(at: link) == requestedPermissions)
        } catch {
            #if canImport(Glibc) || canImport(Musl)
                let platformError = try #require(error as? PlatformError)
                #expect(platformError.kind == .unsupported)
            #else
                throw error
            #endif
        }

        #expect(try capturePermissions(at: target) == targetPermissionsBeforeSet)

    }


    @Test
    func `No-follow permission set handles dangling symlink when supported`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o750)
        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        do {
            try fileSystem.setPosixPermissions(
                forItemAt: link,
                permissions: requestedPermissions,
                followSymlink: false
            )
            #expect(try capturePermissions(at: link) == requestedPermissions)
        } catch {
            #if canImport(Glibc) || canImport(Musl)
                let platformError = try #require(error as? PlatformError)
                #expect(platformError.kind == .unsupported)
            #else
                throw error
            #endif
        }

    }


    @Test
    func `Default permission set fails for dangling symlink`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o640)
        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkPermissionsBeforeSet = try capturePermissions(at: link)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setPosixPermissions(forItemAt: link, permissions: requestedPermissions)
        }

        #expect(error?.kind == .notFound)
        #expect(try capturePermissions(at: link) == linkPermissionsBeforeSet)

    }


    @Test
    func `Setting permissions for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setPosixPermissions(forItemAt: path, permissions: .init(rawValue: 0o640))
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
