import SystemPackage
import Testing
import SwiftFileSystem



extension DirectorySequenceAPITests {

    @Suite("Recursive")
    struct RecursiveTests {

        typealias Support = DirectorySequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension DirectorySequenceAPITests.RecursiveTests {

    struct RecursiveContents {

        var entries = Set<DirectoryEntry>()
        var leavingDirectories = Set<FilePath>()

    }


    func entry(
        _ path: FilePath,
        type: FileKind,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> DirectoryEntry {
        try #require(
            DirectoryEntry(path: path, type: type),
            sourceLocation: sourceLocation
        )
    }


    func recursiveContents(
        from elements: [DirectoryEntryRecursiveSequenceElement]
    ) throws -> RecursiveContents {
        var contents = RecursiveContents()

        for element in elements {
            switch element {
            case .entry(let entry):
                contents.entries.insert(entry)

            case .leavingDir(let path, nil):
                contents.leavingDirectories.insert(path)

            case .leavingDir(_, let error?),
                 .entryError(_, let error),
                 .subTreeError(_, let error):
                throw error
            }
        }

        return contents
    }


    func expectRecursiveDirContents(
        _ contents: RecursiveContents,
        entries expectedEntries: Set<DirectoryEntry>,
        leavingDirectories expectedLeavingDirectories: Set<FilePath>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(contents.entries == expectedEntries, sourceLocation: sourceLocation)
        #expect(
            contents.leavingDirectories == expectedLeavingDirectories,
            sourceLocation: sourceLocation
        )
    }


    func firstIndex(
        ofEntryAt path: FilePath,
        in elements: [DirectoryEntryRecursiveSequenceElement]
    ) -> Int? {
        elements.firstIndex { element in
            if case .entry(let entry) = element { entry.path == path } else { false }
        }
    }


    func firstIndex(
        ofLeavingDirAt path: FilePath,
        in elements: [DirectoryEntryRecursiveSequenceElement]
    ) -> Int? {
        elements.firstIndex { element in
            if case .leavingDir(let dirPath, nil) = element { dirPath == path } else { false }
        }
    }

}



extension DirectorySequenceAPITests.RecursiveTests {

    @Test
    func `Visits the complete tree with leaving-directory markers`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents"),
                    "nested-dir": [
                        "deep": .file(contents: "deep contents")
                    ]
                ],
                "file-link": .symlink(target: "file"),
                "dir-link": .symlink(target: "subdir"),
                "dangling-link": .symlink(target: "missing")
            ]
        )

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let elements = try sequence.map { result in
            try result.get()
        }
        let contents = try recursiveContents(from: elements)

        expectRecursiveDirContents(
            contents,
            entries: [
                try entry("file", type: .regular),
                try entry("subdir", type: .directory),
                try entry("subdir/nested", type: .regular),
                try entry("subdir/nested-dir", type: .directory),
                try entry("subdir/nested-dir/deep", type: .regular),
                try entry("file-link", type: .symlink),
                try entry("dir-link", type: .symlink),
                try entry("dangling-link", type: .symlink)
            ],
            leavingDirectories: [
                "subdir",
                "subdir/nested-dir"
            ]
        )

    }


    @Test
    func `Emits a directory before its children and its leaving marker after them`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents"),
                    "nested-dir": [
                        "deep": .file(contents: "deep contents")
                    ]
                ]
            ]
        )

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let elements = try sequence.map { result in
            try result.get()
        }

        let subdir = try #require(firstIndex(ofEntryAt: "subdir", in: elements))
        let nested = try #require(firstIndex(ofEntryAt: "subdir/nested", in: elements))
        let nestedDir = try #require(firstIndex(ofEntryAt: "subdir/nested-dir", in: elements))
        let deep = try #require(firstIndex(ofEntryAt: "subdir/nested-dir/deep", in: elements))
        let leavingSubdir = try #require(firstIndex(ofLeavingDirAt: "subdir", in: elements))
        let leavingNestedDir = try #require(
            firstIndex(ofLeavingDirAt: "subdir/nested-dir", in: elements)
        )

        #expect(subdir < nested)
        #expect(subdir < nestedDir)
        #expect(nestedDir < deep)
        #expect(deep < leavingNestedDir)
        #expect(leavingNestedDir < leavingSubdir)

    }


    @Test
    func `Skip-dir hides directory markers but still visits descendants`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents"),
                    "nested-dir": [
                        "deep": .file(contents: "deep contents")
                    ]
                ],
                "dir-link": .symlink(target: "subdir")
            ]
        )

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path, options: .skipDir)
        let elements = try sequence.map { result in
            try result.get()
        }
        let contents = try recursiveContents(from: elements)

        expectRecursiveDirContents(
            contents,
            entries: [
                try entry("file", type: .regular),
                try entry("subdir/nested", type: .regular),
                try entry("subdir/nested-dir/deep", type: .regular),
                try entry("dir-link", type: .symlink)
            ],
            leavingDirectories: []
        )

    }


    @Test
    func `Include-dot-entries adds dot entries of every visited directory`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ]
            ]
        )

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path, options: .includeDotEntries)
        let elements = try sequence.map { result in
            try result.get()
        }
        let contents = try recursiveContents(from: elements)

        expectRecursiveDirContents(
            contents,
            entries: [
                try entry(".", type: .directory),
                try entry("..", type: .directory),
                try entry("file", type: .regular),
                try entry("subdir", type: .directory),
                try entry("subdir/.", type: .directory),
                try entry("subdir/..", type: .directory),
                try entry("subdir/nested", type: .regular)
            ],
            leavingDirectories: [
                "subdir"
            ]
        )

    }


    @Test
    func `Directory symlink root traverses its target`() throws {

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

        let sequence = DirectoryEntryRecursiveSequence(dirAt: link)
        let elements = try sequence.map { result in
            try result.get()
        }
        let contents = try recursiveContents(from: elements)

        expectRecursiveDirContents(
            contents,
            entries: [
                try entry("file", type: .regular),
                try entry("subdir", type: .directory),
                try entry("subdir/nested", type: .regular)
            ],
            leavingDirectories: [
                "subdir"
            ]
        )

    }


    @Test
    func `Empty directory yields no elements`() throws {

        let path = try workspace.makeDirectory(at: "empty")

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let elements = try sequence.map { result in
            try result.get()
        }

        #expect(elements.isEmpty)

    }

}
