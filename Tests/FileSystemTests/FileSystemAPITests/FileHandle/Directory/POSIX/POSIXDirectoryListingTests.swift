#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests.DirectoryTests {

    @Suite("POSIX listing")
    struct POSIXListingTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.DirectoryTests.POSIXListingTests {

    private func setPermissions(_ permissions: Int, at path: FilePath) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: path.string
        )
    }


    /// Restores permissions that would otherwise keep the workspace from being cleaned up.
    private func restoreDefaultDirectoryPermissions(at path: FilePath) {
        try? setPermissions(0o755, at: path)
    }

}



extension FileHandleAPITests.DirectoryTests.POSIXListingTests {

    @Test
    func `Entries report the fifo entry kind`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let fifoPath = path.appending("fifo")
        try Support.requireFifoCreationAvailable(at: fifoPath)
        try #require(mkfifo(fifoPath.string, 0o644) == 0)
        let handle = try DirectoryHandle(forDirAt: path)

        let entries = try handle.entries()

        try #require(entries.count == 1)
        #expect(entries[0].path == "fifo")
        #expect(entries[0].type == .fifo)

        try handle.close()

    }


    @Test
    func `Unreadable directory open fails`() throws {

        try Support.requirePermissionChecksEnforced()

        let path = try workspace.makeDirectory(at: "locked")
        try setPermissions(0o000, at: path)
        defer { restoreDefaultDirectoryPermissions(at: path) }

        let error = #expect(throws: PlatformError.self) {
            _ = try DirectoryHandle(forDirAt: path)
        }

        #expect(error?.kind == .permissionDenied)

    }


    @Test
    func `Listing a directory made unreadable after open fails once and ends`() throws {

        try Support.requirePermissionChecksEnforced()

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try DirectoryHandle(forDirAt: path)
        try setPermissions(0o000, at: path)
        defer { restoreDefaultDirectoryPermissions(at: path) }

        // Every listing reopens the directory through the descriptor, so the permission change is
        // observed even though the handle itself stays open.
        let error = #expect(throws: PlatformError.self) {
            _ = try handle.entries()
        }
        #expect(error?.kind == .permissionDenied)

        let sequence = handle.entrySequence()
        var iterator = sequence.makeIterator()
        let firstError = #expect(throws: PlatformError.self) {
            _ = try iterator.next()
        }
        #expect(firstError?.kind == .permissionDenied)
        #expect(try iterator.next() == nil)
        #expect(iterator.ended == true)

    }


    @Test
    func `Open handle outlives directory rename`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let movedPath = workspace.path("moved")
        let handle = try DirectoryHandle(forDirAt: path)

        try FileManager.default.moveItem(atPath: path.string, toPath: movedPath.string)

        // The listing is anchored to the descriptor (`openat(fd, ".")`), so it keeps working after the
        // rename; Windows reopens through the handle as well (see the Windows listing suite).
        try #require(!FileManager.default.fileExists(atPath: path.string))
        let entries = try handle.entries()
        #expect(entries.map(\.name) == ["file"])

        try handle.close()

    }

}

#endif
