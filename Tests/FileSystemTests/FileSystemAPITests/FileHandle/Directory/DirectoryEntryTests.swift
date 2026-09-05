import Testing
import SwiftFileSystem



extension FileHandleAPITests.DirectoryTests {

    @Test
    func `Entries return immediate children without descending or following symlinks`() throws {

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
        let handle = try DirectoryHandle(forDirAt: path)

        let entries = try handle.entries()

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

        try handle.close()

    }


    @Test
    func `Entries return no children for an empty directory`() throws {

        let path = try workspace.makeDirectory(at: "empty")
        let handle = try DirectoryHandle(forDirAt: path)

        let entries = try handle.entries()

        expectEntries(entries, match: [])

        try handle.close()

    }


    @Test
    func `Include-dot-entries adds current and parent directories`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try DirectoryHandle(forDirAt: path)

        let entries = try handle.entries(options: .includeDotEntries)

        expectEntries(
            entries,
            match: [
                try entry(".", type: .directory),
                try entry("..", type: .directory),
                try entry("file", type: .regular)
            ]
        )

        try handle.close()

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
        let handle = try DirectoryHandle(forDirAt: path)

        let entries = try handle.entries(options: .skipDir)

        expectEntries(
            entries,
            match: [
                try entry("file", type: .regular),
                try entry("dir-link", type: .symlink)
            ]
        )

        try handle.close()

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
        let handle = try DirectoryHandle(forDirAt: path)

        let entries = try handle.entries(options: [.includeDotEntries, .skipDir])

        expectEntries(
            entries,
            match: [
                try entry("file", type: .regular)
            ]
        )

        try handle.close()

    }


    @Test
    func `Entries can be listed repeatedly from the same handle`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file-a": .file(contents: "a"),
                "file-b": .file(contents: "b"),
                "subdir": [:]
            ]
        )
        let handle = try DirectoryHandle(forDirAt: path)

        let first = try handle.entries()
        let second = try handle.entries(options: .skipDir)
        let third = try handle.entries()

        expectEntries(
            first,
            match: [
                try entry("file-a", type: .regular),
                try entry("file-b", type: .regular),
                try entry("subdir", type: .directory)
            ]
        )
        expectEntries(
            second,
            match: [
                try entry("file-a", type: .regular),
                try entry("file-b", type: .regular)
            ]
        )
        expectEntries(third, match: Set(first))

        try handle.close()

    }

}
