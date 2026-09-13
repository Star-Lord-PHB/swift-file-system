import Testing
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests.CopyTests {

    /// The roots, the options and the default strategy reach the handler, and the result of a
    /// copy that the driver spreads over several time slices is the same as a synchronous one.
    @Suite("Forwarding")
    struct CopyForwardingTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.CopyTests.CopyForwardingTests {

    @Test
    func `Copies a tree with contents and metadata`() async throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "file contents"),
                "link": .symlink(target: "file.txt"),
                "empty": [:],
                "sub": [
                    "nested.txt": .file(contents: "nested contents"),
                    "inner-link": .symlink(target: "../file.txt"),
                ],
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        try await asyncFileSystem.copyItem(at: src, to: dst)

        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)
        // The copy reads the source, which pushes access times on volumes that maintain them.
        try Support.expectTree(at: src, matches: srcSnapshot, using: .unchanged.excluding(.accessTime))

    }


    @Test
    func `Copies a large file exactly across time slices`() async throws {

        // Far more content than one time slice transfers on any platform measured, so the
        // content steps of this file are resumed across several executor jobs; the slice
        // boundaries must be invisible in the result. Windows copies a file in one step and
        // only proves the passthrough here.
        let src = try workspace.makeLargeFile(at: "src.bin", byteCount: 128 << 20)
        let dst = workspace.path("dst.bin")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try await asyncFileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `Forwards the symlink option`() async throws {

        let srcTarget = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let src = try workspace.makeSymlink(at: "src-link", pointingTo: srcTarget)
        let dst = workspace.path("dst")
        let srcTargetSnapshot = try Support.ItemSnapshot.capture(at: srcTarget)

        try await asyncFileSystem.copyItem(at: src, to: dst, options: .init(symlinkOption: .copyTarget))

        // Under the default `.copyLink` the destination would be a link, so the type check
        // inside the comparison is what proves the options were forwarded.
        try Support.expectItem(at: dst, matches: srcTargetSnapshot, using: .copiedItem)

    }

}
