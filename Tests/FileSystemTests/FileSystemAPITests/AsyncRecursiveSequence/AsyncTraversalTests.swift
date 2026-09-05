import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncRecursiveSequenceAPITests {

    @Suite("Traversal")
    struct TraversalTests {

        typealias Support = AsyncRecursiveSequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: `SwiftFileSystem` is imported for the synchronous `DirectoryEntryRecursiveSequence`
// oracle only: the element order the batches must preserve is the order that sequence yields.
extension AsyncRecursiveSequenceAPITests.TraversalTests {

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


    private func createSampleTree() throws -> FilePath {
        try workspace.makeFixture(
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
    }

}



extension AsyncRecursiveSequenceAPITests.TraversalTests {

    @Test
    func `Visits the complete tree with leaving-directory markers`() async throws {

        let path = try createSampleTree()

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)
        let elements = try await sequence.map { $0 }
        let contents = try recursiveContents(from: elements)

        #expect(sequence.path == path)
        #expect(sequence.executor === AsyncFileSystemExecutor.defaultExecutor)
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


    // Batches of one, two and three elements all cross batch boundaries inside the tree; the
    // element order must be exactly the order the synchronous traversal yields.
    @Test(arguments: [1, 2, 3])
    func `Preserves the traversal order across batch boundaries`(batchCount: Int) async throws {

        let path = try createSampleTree()

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path, batchCount: batchCount)
        let asyncPaths = try await sequence.map { element in
            element.path
        }

        let syncPaths = try DirectoryEntryRecursiveSequence(dirAt: path).map { result in
            try result.get().path
        }
        try #require(syncPaths.count > batchCount)
        #expect(sequence.batchCount == batchCount)
        #expect(asyncPaths == syncPaths)

    }


    @Test
    func `Forwards the skip-dir option`() async throws {

        let path = try createSampleTree()

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path, options: .skipDir)
        let elements = try await sequence.map { $0 }
        let contents = try recursiveContents(from: elements)

        #expect(sequence.options == .skipDir)
        expectRecursiveDirContents(
            contents,
            entries: [
                try entry("file", type: .regular),
                try entry("subdir/nested", type: .regular),
                try entry("subdir/nested-dir/deep", type: .regular),
                try entry("file-link", type: .symlink),
                try entry("dir-link", type: .symlink),
                try entry("dangling-link", type: .symlink)
            ],
            leavingDirectories: []
        )

    }


    @Test
    func `Empty directory yields no elements`() async throws {

        let path = try workspace.makeDirectory(at: "empty")

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeAsyncIterator()

        #expect(iterator.rootPath == path)
        #expect(try await iterator.next() == nil)
        #expect(try await iterator.next() == nil)

    }


    // The same precondition guards the entry sequence of the directory handle; the recursive
    // sequence is constructed without any I/O, so it is the representative.
    @Test
    func `A non-positive batch count traps`() async {

        await #expect(processExitsWith: .failure) {
            _ = AsyncDirectoryEntryRecursiveSequence(dirAt: "/", batchCount: 0)
        }

    }

}
