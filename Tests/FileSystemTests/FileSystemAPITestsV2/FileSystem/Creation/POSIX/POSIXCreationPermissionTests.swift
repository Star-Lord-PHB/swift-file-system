#if !canImport(WinSDK)

import SystemPackage
import Testing
import SwiftFileSystem

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif



extension FileSystemAPITests.CreationTests {

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



extension FileSystemAPITests.CreationTests.POSIXPermissionTests {

    private var defaultFilePermissions: FilePermissions {
        FilePermissions(rawValue: 0o644)
    }

    private var defaultDirectoryPermissions: FilePermissions {
        FilePermissions(rawValue: 0o755)
    }


    private func effectiveCreationMask() throws -> FilePermissions {
        let probe = workspace.path("creation-mask-probe")
        let result = probe.withPlatformString { path in
            mkdir(path, mode_t(0o777))
        }
        try #require(
            result == 0,
            "Failed to create permission probe with errno \(errno)"
        )
        return try capturePermissions(at: probe)
    }


    private func capturePermissions(at path: FilePath) throws -> FilePermissions {
        try Support.ItemMetadata.captureSecurity(at: path).permissions
    }


    @Test
    func `Default file permissions respect umask`() throws {

        let mask = try effectiveCreationMask()
        let path = workspace.path("file")

        try fileSystem.createFile(at: path)

        #expect(
            try capturePermissions(at: path)
                == defaultFilePermissions.intersection(mask)
        )

    }


    @Test
    func `Custom file permissions respect umask`() throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o760)
        let path = workspace.path("file")

        try fileSystem.createFile(
            at: path,
            permissions: requested
        )

        #expect(try capturePermissions(at: path) == requested.intersection(mask))

    }


    @Test
    func `Replace preserves existing file permissions`() throws {

        let initial = FilePermissions(rawValue: 0o640)
        let requested = FilePermissions(rawValue: 0o777)
        let path = try workspace.makeFile(at: "file", contents: "old content")
        try fileSystem.setPosixPermissions(
            forItemAt: path,
            permissions: initial,
            followSymlink: false
        )

        try fileSystem.createFile(
            at: path,
            replaceExisting: true,
            permissions: requested
        )

        #expect(try capturePermissions(at: path) == initial)

    }


    @Test
    func `Default directory permissions respect umask`() throws {

        let mask = try effectiveCreationMask()
        let path = workspace.path("directory")

        try fileSystem.createDirectory(at: path)

        #expect(
            try capturePermissions(at: path)
                == defaultDirectoryPermissions.intersection(mask)
        )

    }


    @Test
    func `Custom directory permissions respect umask`() throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o710)
        let path = workspace.path("directory")

        try fileSystem.createDirectory(
            at: path,
            permissions: requested
        )

        #expect(try capturePermissions(at: path) == requested.intersection(mask))

    }


    @Test
    func `Custom permissions apply only to leaf dir`() throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o700)
        let firstIntermediate = workspace.path("a")
        let secondIntermediate = workspace.path("a/b")
        let leaf = workspace.path("a/b/c")

        try fileSystem.createDirectory(
            at: leaf,
            withIntermediateDirectories: true,
            permissions: requested
        )

        let expectedIntermediate = defaultDirectoryPermissions.intersection(mask)
        #expect(try capturePermissions(at: firstIntermediate) == expectedIntermediate)
        #expect(try capturePermissions(at: secondIntermediate) == expectedIntermediate)
        #expect(try capturePermissions(at: leaf) == requested.intersection(mask))

    }


    @Test
    func `Creation with intermediates preserves existing dir permissions`() throws {

        let initial = FilePermissions(rawValue: 0o711)
        let requested = FilePermissions(rawValue: 0o777)
        let path = try workspace.makeDirectory(at: "directory")
        try fileSystem.setPosixPermissions(
            forItemAt: path,
            permissions: initial,
            followSymlink: false
        )

        try fileSystem.createDirectory(
            at: path,
            withIntermediateDirectories: true,
            permissions: requested
        )

        #expect(try capturePermissions(at: path) == initial)

    }

}

#endif
