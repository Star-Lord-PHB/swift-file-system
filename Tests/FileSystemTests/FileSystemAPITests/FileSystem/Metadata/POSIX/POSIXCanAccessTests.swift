#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import Testing
import SwiftFileSystem
import SystemPackage



extension FileSystemAPITests.MetadataTests {

    @Suite("POSIX access checks")
    struct POSIXCanAccessTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.POSIXCanAccessTests {

    private func setPermissions(
        _ permissions: FilePermissions,
        at path: FilePath
    ) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions.rawValue as NSNumber],
            ofItemAtPath: path.string
        )
    }


    @Test
    func `Default access check requires read and write`() throws {

        guard geteuid() != 0 else {
            try Test.cancel("Root bypasses ordinary POSIX permission checks")
        }

        let readOnlyPath = try workspace.makeFile(at: "read-only")
        try setPermissions(.init(rawValue: 0o400), at: readOnlyPath)
        let writeOnlyPath = try workspace.makeFile(at: "write-only")
        try setPermissions(.init(rawValue: 0o200), at: writeOnlyPath)
        let readWritePath = try workspace.makeFile(at: "read-write")
        try setPermissions(.init(rawValue: 0o600), at: readWritePath)

        #expect(try !fileSystem.canAccess(itemAt: readOnlyPath))
        #expect(try !fileSystem.canAccess(itemAt: writeOnlyPath))
        #expect(try fileSystem.canAccess(itemAt: readWritePath))

    }


    @Test(
        arguments: [
            (FilePermissions(rawValue: 0o400), .read),
            (FilePermissions(rawValue: 0o200), .write),
            (FilePermissions(rawValue: 0o100), .execute),
            (
                FilePermissions(rawValue: 0o700),
                [.read, .write, .execute] as FileOperationOptions.FileAccessMode
            )
        ] as [(FilePermissions, FileOperationOptions.FileAccessMode)]
    )
    func `Granted file permissions allow access`(
        _ permissions: FilePermissions,
        _ mode: FileOperationOptions.FileAccessMode
    ) throws {

        let path = try workspace.makeFile(at: "file")
        try setPermissions(permissions, at: path)

        #expect(try fileSystem.canAccess(itemAt: path, for: mode))

    }


    @Test
    func `Dir permissions allow read write and execute access`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        try setPermissions(.init(rawValue: 0o700), at: path)

        #expect(try fileSystem.canAccess(itemAt: path, for: [.read, .write, .execute]))

    }


    @Test
    func `Denied permissions return false`() throws {

        guard geteuid() != 0 else {
            try Test.cancel("Root bypasses ordinary POSIX permission checks")
        }

        let path = try workspace.makeFile(at: "file")
        try setPermissions(.init(rawValue: 0o000), at: path)

        #expect(try !fileSystem.canAccess(itemAt: path, for: .read))
        #expect(try !fileSystem.canAccess(itemAt: path, for: .write))
        #expect(try !fileSystem.canAccess(itemAt: path, for: .execute))

    }


    @Test
    func `Access check follows symlinks by default`() throws {

        guard geteuid() != 0 else {
            try Test.cancel("Root bypasses ordinary POSIX permission checks")
        }

        let target = try workspace.makeFile(at: "target")
        try setPermissions(.init(rawValue: 0o000), at: target)
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        #expect(try !fileSystem.canAccess(itemAt: link, for: .read))

    }


    @Test
    func `No-follow access check handles symlink itself`() throws {

        guard geteuid() != 0 else {
            try Test.cancel("Root bypasses ordinary POSIX permission checks")
        }

        let target = try workspace.makeFile(at: "target")
        try setPermissions(.init(rawValue: 0o000), at: target)
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        #expect(try fileSystem.canAccess(itemAt: link, for: .read, followSymlink: false))

    }


    @Test
    func `No-follow access check handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        #expect(
            try fileSystem.canAccess(
                itemAt: link,
                for: [.read, .write, .execute],
                followSymlink: false
            )
        )

    }


    @Test
    func `Default access check fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.canAccess(itemAt: link, for: .read)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Missing item access check fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.canAccess(itemAt: path, for: .read)
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
