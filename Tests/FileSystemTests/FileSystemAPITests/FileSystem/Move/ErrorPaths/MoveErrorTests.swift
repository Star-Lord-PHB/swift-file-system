import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MoveTests {

    @Suite("Error paths")
    struct MoveErrorTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MoveTests.MoveErrorTests {

    @Test(arguments: [FileOperationOptions.CopyTargetExistOption.overwrite, .skip, .error])
    func `Missing source fails`(option: FileOperationOptions.CopyTargetExistOption) throws {

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(
                at: workspace.path("missing-src"),
                to: workspace.path("dst"),
                onExistingTarget: option
            )
        }

        #expect(error?.kind == .notFound)

    }


    // The source is checked before the destination on every platform, so a missing source
    // fails even when the option would otherwise skip or reject the existing destination.
    @Test(arguments: [FileOperationOptions.CopyTargetExistOption.overwrite, .skip, .error])
    func `Missing source with existing destination fails`(
        option: FileOperationOptions.CopyTargetExistOption
    ) throws {

        let dst = try workspace.makeFile(at: "dst", contents: "existing contents")
        let dstSnapshot = try Support.ItemSnapshot.capture(at: dst)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: workspace.path("missing-src"), to: dst, onExistingTarget: option)
        }

        #expect(error?.kind == .notFound)
        try Support.expectItem(at: dst, matches: dstSnapshot, using: .unchanged)

    }


    @Test
    func `Move error carries the move operation with both paths`() throws {

        let src = workspace.path("missing-src")
        let dst = workspace.path("dst")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: dst)
        }

        #expect(error?.operation == .move(srcPath: src, dstPath: dst))

    }


    @Test
    func `Missing destination parent fails`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: workspace.path("missing-dir/dst"))
        }

        #expect(error?.kind == .notFound)
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)

    }


    @Test
    func `Destination parent is a file fails`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        try workspace.makeFile(at: "blocker", contents: "not a directory")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: workspace.path("blocker/dst"))
        }

        #if canImport(WinSDK)
        // NOTE: the reported code is volume-configuration-dependent — observed
        // `ERROR_INVALID_PARAMETER` with 8.3 short names enabled and
        // `ERROR_PATH_NOT_FOUND` with them disabled — so only the failure itself
        // is pinned. POSIX reports `ENOTDIR` → `.notADirectory` (see below).
        #expect(error != nil)
        #else
        // NOTE: the Windows kind is volume-configuration-dependent and not pinned
        // (see the branch above).
        #expect(error?.kind == .notADirectory)
        #endif
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)

    }


    @Test
    func `Moving a directory into its own subtree fails`() throws {

        try workspace.makeFile(at: "outer/inner/file", contents: "contents")
        let src = workspace.path("outer")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: workspace.path("outer/inner/moved"))
        }

        #if canImport(WinSDK)
        // NOTE: Windows rejects the cycle with `ERROR_ACCESS_DENIED`, which the replace
        // path reports through the ambiguous kind; POSIX uses `EINVAL`.
        #expect(error?.kind == .windows.permissionDeniedOrIsADirectory)
        #else
        // NOTE: Windows reports its ambiguous access-denied kind for the same cycle
        // (see above).
        #expect(error?.kind == .invalidInput)
        #endif
        // The failed Windows move attempt still opens the source directory and pushes its
        // access time; the root is compared without it, as for copy's containers.
        var expectation = Support.TreeExpectation(matching: srcSnapshot, using: .unchanged)
        try expectation.updatePolicies(["": .unchanged.excluding(.accessTime)])
        try Support.expectTree(at: src, matches: expectation)

    }


    // Same-path moves are a no-op for `.overwrite` and `.skip` on every platform. Only
    // `.error` diverges, so it gets its own test below.
    @Test(arguments: [FileOperationOptions.CopyTargetExistOption.overwrite, .skip])
    func `Moving an item onto its own path is a no-op`(
        option: FileOperationOptions.CopyTargetExistOption
    ) throws {

        let src = try workspace.makeFile(at: "same.txt", contents: "contents")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: src, onExistingTarget: option)

        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)

    }


    @Test
    func `Moving an item onto its own path with existing-target error`() throws {

        let src = try workspace.makeFile(at: "same.txt", contents: "contents")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        #if canImport(Darwin)
        // NOTE: `renamex_np` treats a same-path move as a no-op before the EXCL check;
        // Linux and the BSD simulation see the destination first and report
        // `.alreadyExists`; Windows is volume-dependent (see the branches below).
        try fileSystem.moveItem(at: src, to: src, onExistingTarget: .error)
        #elseif canImport(WinSDK)
        // NOTE: volume-configuration-dependent — a volume with 8.3 short names enabled
        // treats the same-path move as a no-op, one without them reports the collision.
        // Either way the file survives untouched.
        do {
            try fileSystem.moveItem(at: src, to: src, onExistingTarget: .error)
        } catch {
            #expect(error.kind == .alreadyExists)
        }
        #else
        // NOTE: Darwin silently succeeds instead (see the branch above).
        let error = #expect(throws: PlatformError.self) {
            try fileSystem.moveItem(at: src, to: src, onExistingTarget: .error)
        }
        #expect(error?.kind == .alreadyExists)
        #endif
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged)

    }

}
