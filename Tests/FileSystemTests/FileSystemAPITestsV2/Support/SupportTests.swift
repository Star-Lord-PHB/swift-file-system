import Foundation
import SystemPackage
import Testing

@testable import FileSystemCore

@Suite("File-system test support", .catchTestCancellation)
struct FileSystemTestSupportTests {

    typealias Support = FileSystemTestSupport

    @Test
    func `Workspace creates paths and cleans them up explicitly`() throws {

        let workspace = try Support.Workspace(keepArtifacts: false)
        let otherWorkspace = try Support.Workspace(keepArtifacts: false)
        let root = workspace.root

        #expect(FileManager.default.fileExists(atPath: root.string))
        #expect(root != otherWorkspace.root)
        #expect(root.lastComponent?.string.contains("-p\(ProcessInfo.processInfo.processIdentifier)-t") == true)
        #expect(workspace.path("a/../b") == root.appending("b"))
        #if KEEP_FILE_SYSTEM_TEST_WORKSPACES
            #expect(Support.Workspace.defaultKeepArtifacts)
        #else
            #expect(!Support.Workspace.defaultKeepArtifacts)
        #endif

        try workspace.cleanup()

        #expect(!FileManager.default.fileExists(atPath: root.string))

    }

    @Test
    func `Fixture creation and tree snapshots preserve logical structure`() throws {

        let workspace = try Support.Workspace(keepArtifacts: false)
        let fixture = [
            "file.txt": .file(contents: "root contents"),
            "link": .symlink(target: "file.txt"),
            "dangling-link": .symlink(target: "missing.txt"),
            "directory": [
                "nested.txt": .file(contents: "nested contents")
            ],
        ] as Support.Fixture

        let source = try workspace.makeFixture(at: "source", fixture)
        let destination = try workspace.makeFixture(at: "destination", fixture)
        let snapshot = try Support.TreeSnapshot.capture(at: source)

        #expect(snapshot.root.metadata.type == .typeDirectory)
        #expect(snapshot.descendants.count == 5)
        #expect(snapshot["file.txt"]?.payload == .file("root contents"))
        #expect(snapshot["link"]?.payload == .symlinkTarget("file.txt"))
        #expect(snapshot["dangling-link"]?.payload == .symlinkTarget("missing.txt"))
        #expect(snapshot["directory"]?.metadata.type == .typeDirectory)
        #expect(snapshot["directory/nested.txt"]?.payload == .file("nested contents"))

        try Support.expectTree(at: source, matches: snapshot, using: .unchanged)
        try Support.expectTree(at: destination, matches: snapshot, using: .logicalContents)

    }

    @Test
    func `Item snapshots can compare stable unchanged state`() throws {

        let workspace = try Support.Workspace(keepArtifacts: false)
        let path = try workspace.makeFile(at: "file.txt", contents: "contents")
        let snapshot = try Support.ItemSnapshot.capture(at: path)

        #expect(Support.ItemComparisonPolicy.unchanged.fields.contains(.accessTime))
        #expect(Support.ItemComparisonPolicy.unchanged.fields.contains(.statusChangeTime))
        #expect(Support.ItemComparisonPolicy.copiedItem.fields.contains(.accessTime))
        #expect(!Support.ItemComparisonPolicy.copiedItem.fields.contains(.statusChangeTime))
        #expect(Support.ItemComparisonPolicy.unchanged.fields.contains(.creationTime))
        #if canImport(Glibc) || canImport(Musl)
        #expect(!Support.ItemComparisonPolicy.copiedItem.fields.contains(.creationTime))
        #else
        #expect(Support.ItemComparisonPolicy.copiedItem.fields.contains(.creationTime))
        #endif
        #expect(Support.ItemComparisonPolicy.copiedItem.fields.contains(.permissions))
        #expect(
            !Support.ItemComparisonPolicy.copiedItem
                .excluding(.accessTime).fields.contains(.accessTime)
        )
        try Support.expectItem(at: path, matches: snapshot, using: .unchanged)

    }


    @Test
    func `FileTimeSpec conversion preserves timestamp precision`() {

        let timestamp = Support.ItemMetadata.Timestamp(
            secondsSinceUnixEpoch: 1_765_432_100,
            nanoseconds: 123_456_700
        )

        #expect(
            Support.ItemMetadata.Timestamp(
                fileTimeSpec: timestamp.fileTimeSpec
            ) == timestamp
        )

    }


    @Test
    func `FileTimeSpec conversion accounts for platform epoch`() {

        #if canImport(WinSDK)
        let platformSecondsAtUnixEpoch = 11_644_473_600
        #else
        let platformSecondsAtUnixEpoch = 0
        #endif
        let timestamp = Support.ItemMetadata.Timestamp(
            fileTimeSpec: .init(
                seconds: platformSecondsAtUnixEpoch,
                nanoseconds: 0
            )
        )

        #expect(timestamp.secondsSinceUnixEpoch == 0)
        #expect(timestamp.nanoseconds == 0)

    }

    @Test
    func `ageAccessTime moves access time back and preserves modification time`() throws {

        let workspace = try Support.Workspace(keepArtifacts: false)
        let path = try workspace.makeFile(at: "file.txt", contents: "contents")
        let before = try Support.ItemMetadata.Times.capture(at: path)

        try Support.ageAccessTime(at: path)

        let after = try Support.ItemMetadata.Times.capture(at: path)
        Support.expectTimestampEquals(after.access, before.access.adding(seconds: -86_400))
        Support.expectTimestampEquals(after.modification, before.modification)
        #expect(after.access < before.access)

    }

    @Test
    func `volumeUpdatesAccessTimeOnRead matches an observed read`() throws {

        let workspace = try Support.Workspace(keepArtifacts: false)
        let updatesAccessTime = try Support.volumeUpdatesAccessTimeOnRead(in: workspace)

        let path = try workspace.makeFile(at: "file.txt", contents: "contents")
        try Support.ageAccessTime(at: path)
        let before = try Support.ItemMetadata.Times.capture(at: path).access
        let readHandle = try FileHandle(forReadingFrom: URL(filePath: path.string))
        _ = try readHandle.read(upToCount: 1)
        try readHandle.close()
        let after = try Support.ItemMetadata.Times.capture(at: path).access

        #expect((after > before) == updatesAccessTime)

    }

    #if canImport(Darwin) || os(FreeBSD)
    @Test
    func `ageCreationTime lowers birth time and preserves modification time`() throws {

        let workspace = try Support.Workspace(keepArtifacts: false)
        let path = try workspace.makeFile(at: "file.txt", contents: "contents")
        let before = try Support.ItemMetadata.Times.capture(at: path)
        let target = try #require(before.creation).adding(seconds: -86_400)

        try Support.ageCreationTime(at: path, to: target)

        let after = try Support.ItemMetadata.Times.capture(at: path)
        Support.expectTimestampEquals(after.creation, target)
        Support.expectTimestampEquals(after.modification, before.modification)

    }
    #endif

}
