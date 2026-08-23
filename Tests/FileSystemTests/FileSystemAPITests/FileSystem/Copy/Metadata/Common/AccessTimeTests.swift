import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Access time")
    struct AccessTimeTests {

        typealias Support = FileSystemAPITests.Support
        typealias Times = FileSystemTestSupport.ItemMetadata.Times

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.AccessTimeTests {

    /// Cancels when the volume does not push access times on reads: the tests here
    /// observe that push or prove it was undone, and neither works without it.
    private func requireAccessTimeUpdates(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        if try !Support.volumeUpdatesAccessTimeOnRead(in: workspace, sourceLocation: sourceLocation) {
            try Test.cancel(
                "The volume does not update access times on read",
                sourceLocation: sourceLocation
            )
        }
    }


    /// Ages the item's access time and captures the resulting times.
    ///
    /// Nothing may read the item's contents (or enumerate it, for a directory) between
    /// this call and the copy, or the aged access time is pushed before the copy can
    /// cache it.
    private func ageAccessTimeAndCapture(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Times {
        try Support.ageAccessTime(at: path, sourceLocation: sourceLocation)
        return try Times.capture(at: path, sourceLocation: sourceLocation)
    }


    #if !canImport(WinSDK)
    @Test
    func `Copy pushes the source access time by default`() throws {

        // NOTE: This is POSIX-only; on Windows `CopyFileEx` leaves the source access
        // time unchanged (see the Windows counterpart of this test).
        try requireAccessTimeUpdates()

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let before = try ageAccessTimeAndCapture(at: src)

        try fileSystem.copyItem(at: src, to: workspace.path("dst.txt"))

        let after = try Times.capture(at: src)
        #expect(after.access > before.access)
        #expect(after.modification == before.modification)

    }
    #endif


    #if canImport(WinSDK)
    @Test
    func `Copy keeps the source access time by default`() throws {

        // NOTE: `CopyFileEx` restores the source access time on its own, even though
        // plain reads on the same volume push it (the probe above proves the volume
        // maintains access times). POSIX reads the source through a regular handle and
        // does push it — see the POSIX counterpart of this test.
        try requireAccessTimeUpdates()

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let before = try ageAccessTimeAndCapture(at: src)

        try fileSystem.copyItem(at: src, to: workspace.path("dst.txt"))

        let after = try Times.capture(at: src)
        #expect(after.access == before.access)
        #expect(after.modification == before.modification)

    }
    #endif


    @Test
    func `Destination receives the source access time cached before the copy`() throws {

        // No volume probe: the destination times are written explicitly from the cached
        // source values, which works whether or not the volume pushes access times.
        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let dst = workspace.path("dst.txt")
        let srcBefore = try ageAccessTimeAndCapture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        let dstTimes = try Times.capture(at: dst)
        #expect(dstTimes.access == srcBefore.access)
        #expect(dstTimes.modification == srcBefore.modification)

    }


    @Test
    func `preserveSrcAccessTime restores the source file access time`() throws {

        try requireAccessTimeUpdates()

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let before = try ageAccessTimeAndCapture(at: src)

        try fileSystem.copyItem(
            at: src,
            to: workspace.path("dst.txt"),
            options: .init(preserveSrcAccessTime: true)
        )

        let after = try Times.capture(at: src)
        #expect(after.access == before.access)
        #expect(after.modification == before.modification)

    }


    #if canImport(Darwin)
    @Test
    func `Restoring the access time keeps the status-change time`() throws {

        // NOTE: APFS does not dirty the status-change time when an access time is
        // written back; on Linux the same restore pushes it (see the Linux-only
        // counterpart of this test).
        try requireAccessTimeUpdates()

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let before = try ageAccessTimeAndCapture(at: src)

        try fileSystem.copyItem(
            at: src,
            to: workspace.path("dst.txt"),
            options: .init(preserveSrcAccessTime: true)
        )

        let after = try Times.capture(at: src)
        #expect(after.access == before.access)
        #expect(after.statusChange == before.statusChange)

    }
    #endif


    #if canImport(Glibc) || canImport(Musl)
    @Test
    func `Restoring the access time updates the status-change time`() throws {

        // NOTE: POSIX semantics push the status-change time when the access time is
        // written back; macOS/APFS leaves it untouched (see the Darwin-only
        // counterpart of this test). Source-side "unchanged" assertions after a
        // preserving copy must therefore not include the status-change time on Linux.
        try requireAccessTimeUpdates()

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let before = try ageAccessTimeAndCapture(at: src)

        try fileSystem.copyItem(
            at: src,
            to: workspace.path("dst.txt"),
            options: .init(preserveSrcAccessTime: true)
        )

        let after = try Times.capture(at: src)
        #expect(after.access == before.access)
        #expect(after.statusChange > before.statusChange)

    }
    #endif


    @Test
    func `preserveSrcAccessTime restores directory access times across a tree`() throws {

        try requireAccessTimeUpdates()

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "file contents"),
                "sub": [
                    "nested.txt": .file(contents: "nested contents")
                ],
            ]
        )
        let dst = workspace.path("dst")
        let relativePaths = ["", "file.txt", "sub", "sub/nested.txt"]
        var srcTimesBefore = [Times]()
        for item in relativePaths {
            srcTimesBefore.append(try ageAccessTimeAndCapture(at: src.appending(item)))
        }

        try fileSystem.copyItem(at: src, to: dst, options: .init(preserveSrcAccessTime: true))

        // Directories are read during traversal and restored when they are left;
        // files are restored right after their contents are read.
        for (item, expected) in zip(relativePaths, srcTimesBefore) {
            let srcAfter = try Times.capture(at: src.appending(item))
            #expect(srcAfter.access == expected.access, "src item: \(item)")
        }
        // The destination receives the cached (aged) values regardless of the option.
        for (item, expected) in zip(relativePaths, srcTimesBefore) {
            let dstTimes = try Times.capture(at: dst.appending(item))
            #expect(dstTimes.access == expected.access, "dst item: \(item)")
            #expect(dstTimes.modification == expected.modification, "dst item: \(item)")
        }

    }


    @Test
    func `Skip merge restores each skipped directory's own access time`() throws {

        try requireAccessTimeUpdates()

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "new.txt": .file(contents: "src new")
                ]
            ]
        )
        let dst = try workspace.makeFixture(at: "dst", ["sub": [:]])
        let srcSub = src.appending("sub")
        let srcNew = srcSub.appending("new.txt")
        let srcBefore = try ageAccessTimeAndCapture(at: src)
        let srcSubBefore = try ageAccessTimeAndCapture(at: srcSub)
        let srcNewBefore = try ageAccessTimeAndCapture(at: srcNew)

        try fileSystem.copyItem(
            at: src,
            to: dst,
            options: .init(existingTarget: .skip, preserveSrcAccessTime: true)
        )

        // A skipped directory restores its own pre-copy access time, not anything
        // derived from the existing destination.
        #expect(try Times.capture(at: src).access == srcBefore.access)
        #expect(try Times.capture(at: srcSub).access == srcSubBefore.access)
        #expect(try Times.capture(at: srcNew).access == srcNewBefore.access)
        // The missing file is still copied into the skipped directory, with cached times.
        let dstNewTimes = try Times.capture(at: dst.appending("sub/new.txt"))
        #expect(dstNewTimes.access == srcNewBefore.access)
        #expect(dstNewTimes.modification == srcNewBefore.modification)

    }


    @Test
    func `Abort restores source directory access times and skips destination times`() throws {

        try requireAccessTimeUpdates()

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "clash": [
                        "inner.txt": .file(contents: "src inner")
                    ]
                ]
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "sub": [
                    "clash": .file(contents: "dst clash")
                ]
            ]
        )
        let srcSub = src.appending("sub")
        let dstSub = dst.appending("sub")
        let srcBefore = try ageAccessTimeAndCapture(at: src)
        let srcSubBefore = try ageAccessTimeAndCapture(at: srcSub)
        let dstBefore = try Times.capture(at: dst)
        let dstSubBefore = try Times.capture(at: dstSub)

        #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(
                at: src,
                to: dst,
                options: .init(preserveSrcAccessTime: true),
                errorStrategy: .abortOnError
            )
        }

        // The abort's cleanup restores every source directory still being traversed.
        #expect(try Times.capture(at: src).access == srcBefore.access)
        #expect(try Times.capture(at: srcSub).access == srcSubBefore.access)
        // The unfinished destination directories never receive the source times. Their
        // access times cannot be compared to their own pre-copy values (on Windows the
        // failed creation attempt for an existing directory pushes its parent's access
        // time), but they must never become the source's aged values.
        let dstAfter = try Times.capture(at: dst)
        #expect(dstAfter.modification == dstBefore.modification)
        #expect(dstAfter.creation == dstBefore.creation)
        #expect(dstAfter.access != srcBefore.access)
        let dstSubAfter = try Times.capture(at: dstSub)
        #expect(dstSubAfter.modification == dstSubBefore.modification)
        #expect(dstSubAfter.creation == dstSubBefore.creation)
        #expect(dstSubAfter.access != srcSubBefore.access)

    }

}
