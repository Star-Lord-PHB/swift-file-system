import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests.DirectoryTests {

    @Suite("Entry sequence")
    struct EntrySequenceTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.DirectoryTests.EntrySequenceTests {

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
    func `Enumerates immediate children`() throws {

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

        let sequence = handle.entrySequence()
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


    @Test
    func `Forwards traversal options`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [:],
                "dir-link": .symlink(target: "subdir")
            ]
        )
        let handle = try DirectoryHandle(forDirAt: path)

        let sequence = handle.entrySequence(options: .skipDir)
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
    func `Can be iterated more than once`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file-a": .file(contents: "a"),
                "file-b": .file(contents: "b"),
                "subdir": [:]
            ]
        )
        let handle = try DirectoryHandle(forDirAt: path)

        let sequence = handle.entrySequence()
        let first = try sequence.map { result in
            try result.get()
        }
        let second = try sequence.map { result in
            try result.get()
        }

        expectEntries(
            first,
            match: [
                try entry("file-a", type: .regular),
                try entry("file-b", type: .regular),
                try entry("subdir", type: .directory)
            ]
        )
        expectEntries(second, match: Set(first))

    }


    @Test
    func `Iterators of one sequence advance independently`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file-a": .file(contents: "a"),
                "file-b": .file(contents: "b"),
                "file-c": .file(contents: "c")
            ]
        )
        let handle = try DirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        var first = sequence.makeIterator()
        var second = sequence.makeIterator()

        let head = first.next()
        let headEntry = try #require(head).get()

        var secondEntries = [DirectoryEntry]()
        while let result = second.next() {
            secondEntries.append(try result.get())
        }

        var firstRemainder = [DirectoryEntry]()
        while let result = first.next() {
            firstRemainder.append(try result.get())
        }

        let expected: Set<DirectoryEntry> = [
            try entry("file-a", type: .regular),
            try entry("file-b", type: .regular),
            try entry("file-c", type: .regular)
        ]
        expectEntries(secondEntries, match: expected)
        expectEntries([headEntry] + firstRemainder, match: expected)
        #expect(first.ended == true)
        #expect(second.ended == true)
        #expect(first.rootPath == path)

    }

}
