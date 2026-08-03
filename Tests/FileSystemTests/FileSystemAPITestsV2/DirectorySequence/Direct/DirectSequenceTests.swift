import SystemPackage
import Testing
import SwiftFileSystem



extension DirectorySequenceAPITests {

    @Suite("Direct")
    struct DirectTests {

        typealias Support = DirectorySequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension DirectorySequenceAPITests.DirectTests {

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


    private func expectEntries(
        _ entries: [DirectoryEntry],
        match expected: Set<DirectoryEntry>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(entries.count == expected.count, sourceLocation: sourceLocation)
        #expect(Set(entries) == expected, sourceLocation: sourceLocation)
    }


    @Test
    func `Enumerates immediate children without descending or following symlinks`() throws {

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

        let sequence = try DirectoryEntryDirectSequence(dirAt: path)
        let entries = try sequence.map { result in
            try result.get()
        }

        expectEntries(
            entries,
            match: [
                try entry("file", type: .regular),
                try entry("subdir", type: .directory),
                try entry("file-link", type: .symlink),
                try entry("dir-link", type: .symlink),
                try entry("dangling-link", type: .symlink)
            ]
        )

    }


    @Test
    func `Empty directory yields no entries`() throws {

        let path = try workspace.makeDirectory(at: "empty")

        let sequence = try DirectoryEntryDirectSequence(dirAt: path)
        let entries = try sequence.map { result in
            try result.get()
        }

        expectEntries(entries, match: [])

    }


    @Test
    func `Include-dot-entries adds current and parent directories`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )

        let sequence = try DirectoryEntryDirectSequence(dirAt: path, options: .includeDotEntries)
        let entries = try sequence.map { result in
            try result.get()
        }

        expectEntries(
            entries,
            match: [
                try entry(".", type: .directory),
                try entry("..", type: .directory),
                try entry("file", type: .regular)
            ]
        )

    }


    @Test
    func `Skip-dir excludes directories but keeps symlinks`() throws {

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

        let sequence = try DirectoryEntryDirectSequence(dirAt: path, options: .skipDir)
        let entries = try sequence.map { result in
            try result.get()
        }

        expectEntries(
            entries,
            match: [
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

        let sequence = try DirectoryEntryDirectSequence(
            dirAt: path,
            options: [.includeDotEntries, .skipDir]
        )
        let entries = try sequence.map { result in
            try result.get()
        }

        expectEntries(
            entries,
            match: [
                try entry("file", type: .regular)
            ]
        )

    }


    @Test
    func `Directory symlink root enumerates its target`() throws {

        let target = try workspace.makeFixture(
            at: "target",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ]
            ]
        )
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let sequence = try DirectoryEntryDirectSequence(dirAt: link)
        let entries = try sequence.map { result in
            try result.get()
        }

        expectEntries(
            entries,
            match: [
                try entry("file", type: .regular),
                try entry("subdir", type: .directory)
            ]
        )

    }

}
