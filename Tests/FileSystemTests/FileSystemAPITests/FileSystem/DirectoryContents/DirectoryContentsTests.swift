import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Directory contents")
    struct DirectoryContentsTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.DirectoryContentsTests {

    private func entry(
        _ path: FilePath,
        type: FileKind,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> DirectoryEntry {
        try #require(
            DirectoryEntry(path: path, type: type),
            sourceLocation: sourceLocation
        )
    }


    private func expectContents(
        _ contents: [DirectoryEntry],
        matches expected: Set<DirectoryEntry>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(contents.count == expected.count, sourceLocation: sourceLocation)
        #expect(Set(contents) == expected, sourceLocation: sourceLocation)
    }


    @Test
    func `Default options return immediate entries`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ],
                "file-link": .symlink(target: "file"),
                "dir-link": .symlink(target: "subdir"),
                "dangling-link": .symlink(target: "missing")
            ]
        )

        let contents = try fileSystem.contentsOfDirectory(at: path)

        expectContents(
            contents,
            matches: [
                try entry("file", type: .regular),
                try entry("subdir", type: .directory),
                try entry("file-link", type: .symlink),
                try entry("dir-link", type: .symlink),
                try entry("dangling-link", type: .symlink)
            ]
        )

    }


    @Test
    func `Default options return no entries for an empty dir`() throws {

        let path = try workspace.makeDirectory(at: "empty")

        let contents = try fileSystem.contentsOfDirectory(at: path)

        expectContents(contents, matches: [])

    }


    @Test
    func `Include-dot-entries returns current and parent dirs`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let contents = try fileSystem.contentsOfDirectory(
            at: path,
            options: .includeDotEntries
        )

        expectContents(
            contents,
            matches: [
                try entry(".", type: .directory),
                try entry("..", type: .directory)
            ]
        )

    }


    @Test
    func `Skip-dir excludes dirs but keeps symlinks`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ],
                "dir-link": .symlink(target: "subdir")
            ]
        )

        let contents = try fileSystem.contentsOfDirectory(
            at: path,
            options: .skipDir
        )

        expectContents(
            contents,
            matches: [
                try entry("file", type: .regular),
                try entry("dir-link", type: .symlink)
            ]
        )

    }


    @Test
    func `Skip-dir also excludes included dot entries`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ]
            ]
        )

        let contents = try fileSystem.contentsOfDirectory(
            at: path,
            options: [.includeDotEntries, .skipDir]
        )

        expectContents(
            contents,
            matches: [
                try entry("file", type: .regular)
            ]
        )

    }


    @Test
    func `Directory symlink enumerates its target`() throws {

        let target = try workspace.makeFixture(
            at: "target",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ]
            ]
        )
        let link = try workspace.makeSymlink(
            at: "link",
            pointingTo: target
        )

        let contents = try fileSystem.contentsOfDirectory(at: link)

        expectContents(
            contents,
            matches: [
                try entry("file", type: .regular),
                try entry("subdir", type: .directory)
            ]
        )

    }


    @Test
    func `Missing directory fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.contentsOfDirectory(at: path)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Regular file fails as a directory`() throws {

        let path = try workspace.makeFile(at: "file")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.contentsOfDirectory(at: path)
        }

        #expect(error?.kind == .notADirectory)

    }

}
