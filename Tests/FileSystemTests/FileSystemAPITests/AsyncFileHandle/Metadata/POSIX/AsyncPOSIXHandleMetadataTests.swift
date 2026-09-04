#if !canImport(WinSDK)

import Foundation
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("POSIX forwarding")
    struct POSIXForwardingTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The POSIX permission shells are conditional source; `setOwner` is a single
// cross-platform shell whose successful forwarding can only be shown here, with a replacement
// group (no candidate cancels the test, as in the synchronous ownership suite).
extension AsyncFileHandleAPITests.MetadataTests.POSIXForwardingTests {

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
    func `posixPermissions matches stat`() async throws {

        let path = try workspace.makeFile(at: "file")
        try setFoundationPermissions(FilePermissions(rawValue: 0o640), at: path)
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        let permissions = try await handle.posixPermissions()

        #expect(try permissions == capturePermissions(at: path))
        #expect(permissions == FilePermissions(rawValue: 0o640))

        try await handle.close()

    }


    @Test
    func `setPosixPermissions forwards permissions`() async throws {

        let path = try workspace.makeFile(at: "file")
        let requested = FilePermissions(rawValue: 0o640)
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        try await handle.setPosixPermissions(requested)

        try await handle.close()

        #expect(try capturePermissions(at: path) == requested)

    }


    @Test
    func `setOwner forwards the replacement group`() async throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try Support.ItemMetadata.captureSecurity(at: path).ownership
        guard
            let replacementGroup = try Support.replacementGroup(
                excluding: ownershipBeforeSet.group.rawId
            )
        else {
            try Test.cancel("No alternate group is available to the current process")
        }
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        try await handle.setOwner(owner: nil, group: replacementGroup)

        try await handle.close()

        let ownershipAfterSet = try Support.ItemMetadata.captureSecurity(at: path).ownership
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == replacementGroup)

    }


    @Test
    func `Pre-cancelled posixPermissions reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.posixPermissions()
        }

    }


    @Test
    func `Pre-cancelled setPosixPermissions reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.setPosixPermissions(FilePermissions(rawValue: 0o640))
        }

    }

}

#endif
