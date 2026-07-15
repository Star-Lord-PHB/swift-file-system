import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Removal")
    struct RemovalTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.RemovalTests {

    @Test
    func `Removes a regular file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")

        try fileSystem.removeItem(at: path)

        try Support.expectItemNotExistNoFollow(at: path)

    }


    @Test
    func `Removes an empty directory`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        try fileSystem.removeItem(at: path)

        try Support.expectItemNotExistNoFollow(at: path)

    }


    @Test
    func `Recursively removes a non-empty directory`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "root contents"),
                "nested": [
                    "file": .file(contents: "nested contents"),
                    "deep": [
                        "file": .file(contents: "deep contents")
                    ]
                ]
            ] as Support.Fixture
        )

        try fileSystem.removeItem(at: path)

        try Support.expectItemNotExistNoFollow(at: path)

    }


    @Test
    func `Removes a file symlink without touching its target`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetSnapshot = try Support.ItemSnapshot.capture(at: target)

        try fileSystem.removeItem(at: link)

        try Support.expectItemNotExistNoFollow(at: link)
        try Support.expectItem(at: target, matches: targetSnapshot, using: .unchanged)

    }


    @Test
    func `Removes a dir symlink without touching its target`() throws {

        let target = try workspace.makeFixture(
            at: "target",
            [
                "file": .file(contents: "target contents"),
                "nested": [
                    "file": .file(contents: "nested contents")
                ],
            ] as Support.Fixture
        )
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetSnapshot = try Support.TreeSnapshot.capture(at: target)

        try fileSystem.removeItem(at: link)

        try Support.expectItemNotExistNoFollow(at: link)
        try Support.expectTree(at: target, matches: targetSnapshot, using: .unchanged)

    }


    @Test
    func `Removes a dangling symlink`() throws {

        let missingTarget = workspace.path("missing-target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: missingTarget)

        try fileSystem.removeItem(at: link)

        try Support.expectItemNotExistNoFollow(at: link)

    }


    @Test
    func `Recursive removal does not follow symlinks`() throws {

        let fileTarget = try workspace.makeFile(
            at: "file-target",
            contents: "external file contents"
        )
        let dirTarget = try workspace.makeFixture(
            at: "dir-target",
            [
                "file": .file(contents: "external directory contents")
            ] as Support.Fixture
        )
        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file-link": .symlink(target: fileTarget),
                "dir-link": .symlink(target: dirTarget),
                "dangling-link": .symlink(target: workspace.path("missing-target")),
            ] as Support.Fixture
        )
        let fileTargetSnapshot = try Support.ItemSnapshot.capture(at: fileTarget)
        let dirTargetSnapshot = try Support.TreeSnapshot.capture(at: dirTarget)

        try fileSystem.removeItem(at: path)

        try Support.expectItemNotExistNoFollow(at: path)
        try Support.expectItem(at: fileTarget, matches: fileTargetSnapshot, using: .unchanged)
        try Support.expectTree(at: dirTarget, matches: dirTargetSnapshot, using: .unchanged)

    }


    @Test
    func `Missing item removal fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: path)
        }

        #expect(error?.kind == .notFound)

    }

}
