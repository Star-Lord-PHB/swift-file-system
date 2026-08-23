#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MoveTests {

    @Suite("POSIX")
    struct MovePOSIXTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MoveTests.MovePOSIXTests {

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


    @Test
    func `Read-only source parent denies the move`() throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

        let src = try workspace.makeFile(at: "src-parent/src.txt", contents: "contents")
        let srcParent = workspace.path("src-parent")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        try setPermissions(0o555, at: srcParent)
        defer { restoreDefaultDirectoryPermissions(at: srcParent) }

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: workspace.path("dst.txt"))
        }

        #expect(error?.kind == .permissionDenied)
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectItemNotExistNoFollow(at: workspace.path("dst.txt"))

    }


    @Test
    func `Read-only destination parent denies the move`() throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let dstParent = try workspace.makeDirectory(at: "dst-parent")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        try setPermissions(0o555, at: dstParent)
        defer { restoreDefaultDirectoryPermissions(at: dstParent) }

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: workspace.path("dst-parent/dst.txt"))
        }

        #expect(error?.kind == .permissionDenied)
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectItemNotExistNoFollow(at: workspace.path("dst-parent/dst.txt"))

    }


    // NOTE: Windows refuses to replace a READONLY destination instead; POSIX only
    // consults the directory permissions (see the Windows platform suite).
    @Test
    func `Overwrite replaces a read-only destination file`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dst = try workspace.makeFile(at: "dst.txt", contents: "existing contents")
        try setPermissions(0o444, at: dst)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .movedItem)
        try Support.expectItemNotExistNoFollow(at: src)

    }

}

#endif
