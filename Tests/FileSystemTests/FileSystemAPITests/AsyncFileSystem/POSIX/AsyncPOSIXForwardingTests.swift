#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem
import SystemPackage



extension AsyncFileSystemAPITests {

    @Suite("POSIX forwarding")
    struct POSIXForwardingTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let fileSystem = FileSystem()
        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.POSIXForwardingTests {

    private func capturePermissions(at path: FilePath) throws -> FilePermissions {
        try Support.ItemMetadata.captureSecurity(at: path).permissions
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
    func `createFile forwards creation permissions`() async throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o760)
        let path = workspace.path("file")

        try await asyncFileSystem.createFile(at: path, permissions: requested)

        #expect(try capturePermissions(at: path) == requested.intersection(mask))

    }


    @Test
    func `createDirectory forwards creation permissions`() async throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o750)
        let path = workspace.path("directory")

        try await asyncFileSystem.createDirectory(at: path, permissions: requested)

        #expect(try capturePermissions(at: path) == requested.intersection(mask))

    }


    @Test
    func `posixPermissions matches stat`() async throws {

        let path = try workspace.makeFile(at: "file")
        try setFoundationPermissions(FilePermissions(rawValue: 0o640), at: path)

        let permissions = try await asyncFileSystem.posixPermissions(ofItemAt: path)

        #expect(try permissions == capturePermissions(at: path))
        #expect(permissions == FilePermissions(rawValue: 0o640))

    }


    @Test
    func `setPosixPermissions forwards permissions`() async throws {

        let path = try workspace.makeFile(at: "file")
        let requested = FilePermissions(rawValue: 0o640)

        try await asyncFileSystem.setPosixPermissions(forItemAt: path, permissions: requested)

        #expect(try capturePermissions(at: path) == requested)

    }


    @Test
    func `setOwner forwards the replacement group`() async throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try Support.ItemMetadata.captureSecurity(at: path).ownership
        let replacementGroup = try Support.requireReplacementGroup(
            excluding: ownershipBeforeSet.group.rawId
        )

        try await asyncFileSystem.setOwner(forItemAt: path, owner: nil, group: replacementGroup)

        let ownershipAfterSet = try Support.ItemMetadata.captureSecurity(at: path).ownership
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == replacementGroup)

    }


    @Test
    func `canAccess forwards the access mode`() async throws {

        try Support.requirePermissionChecksEnforced()

        let path = try workspace.makeFile(at: "file")
        try setFoundationPermissions(FilePermissions(rawValue: 0o400), at: path)

        #expect(try await asyncFileSystem.canAccess(itemAt: path) == false)
        #expect(try await asyncFileSystem.canAccess(itemAt: path, for: [.read]))

    }


    @Test
    func `Pre-cancelled posixPermissions reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.posixPermissions(ofItemAt: path)
        }

    }


    @Test
    func `Pre-cancelled setPosixPermissions reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.setPosixPermissions(forItemAt: path, permissions: [])
        }

    }

}

#endif
