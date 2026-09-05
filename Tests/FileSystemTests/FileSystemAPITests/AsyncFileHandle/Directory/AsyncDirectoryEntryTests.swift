import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.DirectoryTests {

    @Test
    func `Entries return immediate children without descending or following symlinks`() async throws {

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
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        let entries = try await handle.entries()

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

        try await handle.close()

    }


    @Test
    func `Entries forward the dot-entries option`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        let entries = try await handle.entries(options: .includeDotEntries)

        expectEntries(
            entries,
            match: [
                try entry(".", type: .directory),
                try entry("..", type: .directory),
                try entry("file", type: .regular)
            ]
        )

        try await handle.close()

    }


    @Test
    func `Entries forward the skip-dir option`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [:],
                "dir-link": .symlink(target: "subdir")
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        let entries = try await handle.entries(options: .skipDir)

        expectEntries(
            entries,
            match: [
                try entry("file", type: .regular),
                try entry("dir-link", type: .symlink)
            ]
        )

        try await handle.close()

    }


    @Test
    func `Entries can be listed repeatedly from the same handle`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file-a": .file(contents: "a"),
                "file-b": .file(contents: "b"),
                "subdir": [:]
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        let first = try await handle.entries()
        let second = try await handle.entries(options: .skipDir)
        let third = try await handle.entries()

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

        try await handle.close()

    }


    @Test
    func `Pre-cancelled entries reports cancellation`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        await Support.expectPreCancelled {
            try await handle.entries()
        }

    }

}
