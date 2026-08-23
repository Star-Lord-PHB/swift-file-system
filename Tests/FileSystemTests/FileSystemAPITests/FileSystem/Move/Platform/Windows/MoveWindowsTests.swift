#if canImport(WinSDK)

import WinSDK
import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MoveTests {

    @Suite("Windows")
    struct MoveWindowsTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MoveTests.MoveWindowsTests {

    private func setNativeAttributes(
        _ attributes: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let success = path.withPlatformString { pathPointer in
            SetFileAttributesW(pathPointer, attributes.rawValue)
        }
        try #require(success, sourceLocation: sourceLocation)
    }


    /// READONLY blocks deletion and would break the workspace cleanup; call from a `defer`.
    private func clearNativeAttributes(at path: FilePath) {
        _ = path.withPlatformString { pathPointer in
            SetFileAttributesW(pathPointer, PlatformFileAttributes.windows.isNormal.rawValue)
        }
    }


    // NOTE: POSIX replaces a read-only destination file, permissions there only live on
    // the directory (see the POSIX platform suite).
    @Test
    func `Overwrite of a READONLY destination fails`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dst = try workspace.makeFile(at: "dst.txt", contents: "existing contents")
        try setNativeAttributes(.windows.isReadOnly, at: dst)
        defer { clearNativeAttributes(at: dst) }
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dstSnapshot = try Support.ItemSnapshot.capture(at: dst)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)
        }

        // The replacement is rejected with `ERROR_ACCESS_DENIED`, which this call site
        // cannot tell apart from a directory destination.
        #expect(error?.kind == .windows.permissionDeniedOrIsADirectory)
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)
        try Support.expectItem(at: dst, matches: dstSnapshot, using: .unchanged)

    }


    // Overwrite treats a junction like any other non-directory entry: the junction
    // itself is replaced and its target tree is untouched. (Copy instead reports
    // junctions as unsupported; move never resolves the entry, so there is nothing
    // to misinterpret.)
    @Test
    func `Overwrite replaces a junction destination`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        try workspace.makeFile(at: "junction-target/child", contents: "child contents")
        let dstTarget = workspace.path("junction-target")
        let dst = workspace.path("dst-junction")
        try Support.makeWindowsJunction(at: dst, pointingTo: dstTarget)
        let dstTargetSnapshot = try Support.TreeSnapshot.capture(at: dstTarget)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)

        try Support.expectItem(
            at: dst,
            matches: srcSnapshot,
            using: FileSystemAPITests.MoveTests.replacedItemPolicy
        )
        try Support.expectItemNotExistNoFollow(at: src)
        try Support.expectTree(at: dstTarget, matches: dstTargetSnapshot, using: .unchanged)

    }


    // The cross-platform matrix asserts `kind.maybe(.isADirectory)`; the exact Windows
    // kind for a directory destination is pinned once here.
    @Test
    func `Overwrite onto a directory reports the ambiguous kind`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "new contents")
        let dst = try workspace.makeDirectory(at: "dst-dir")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: dst, onExistingTarget: .overwrite)
        }

        #expect(error?.kind == .windows.permissionDeniedOrIsADirectory)
        try Support.expectItemExistNoFollow(at: src)

    }

}

#endif
