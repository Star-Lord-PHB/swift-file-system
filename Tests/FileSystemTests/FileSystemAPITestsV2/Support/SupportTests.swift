import Foundation
import SystemPackage
import Testing

@testable import FileSystemCore

@Suite("File-system test support")
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
        #expect(Support.ItemComparisonPolicy.copiedItem.fields.contains(.creationTime))
        try Support.expectItem(at: path, matches: snapshot, using: .unchanged)

    }

}
