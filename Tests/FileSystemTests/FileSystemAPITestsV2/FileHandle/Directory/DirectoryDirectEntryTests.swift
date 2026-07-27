import Testing
import SwiftFileSystem



extension FileHandleAPITests.DirectoryTests {

    @Test
    func `Direct entries return immediate children`() throws {

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

        let entries = try handle.directEntries()

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
    func `Direct entries return no children for an empty directory`() throws {

        let path = try workspace.makeDirectory(at: "empty")
        let handle = try DirectoryHandle(forDirAt: path)

        let entries = try handle.directEntries()

        expectEntries(entries, match: [])

        try handle.close()

    }


    @Test
    func `Direct entries can include current and parent directories`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let handle = try DirectoryHandle(forDirAt: path)

        let entries = try handle.directEntries(options: .includeDotEntries)

        expectEntries(
            entries,
            match: [
                try entry(".", type: .directory),
                try entry("..", type: .directory)
            ]
        )

        try handle.close()

    }


    @Test
    func `Direct entries can exclude directories while retaining symlinks`() throws {

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

        let entries = try handle.directEntries(options: .skipDir)

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
    func `Direct entry sequence enumerates immediate children`() throws {

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

        let entries: [DirectoryEntry]
        do {
            let sequence = handle.entryDirectSequence()
            entries = try sequence.map { result in
                try result.get()
            }
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
