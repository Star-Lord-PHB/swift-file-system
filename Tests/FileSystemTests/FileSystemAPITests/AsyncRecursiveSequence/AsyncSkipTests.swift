import SystemPackage
import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncRecursiveSequenceAPITests {

    @Suite("Skip")
    struct SkipTests {

        typealias Support = AsyncRecursiveSequenceAPITests.Support
        typealias ElementShape = AsyncRecursiveSequenceAPITests.ElementShape
        typealias SkipAction = AsyncRecursiveSequenceAPITests.SkipAction
        typealias SkipTrigger = AsyncRecursiveSequenceAPITests.SkipTrigger

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: `SwiftFileSystem` is imported for the synchronous oracle only; see `AsyncSkipSupport.swift`.
extension AsyncRecursiveSequenceAPITests.SkipTests {

    struct Scenario: Sendable, CustomStringConvertible {

        let name: String
        let options: FileOperationOptions.DirectoryTraversalOption
        let before: [SkipAction]
        let triggers: [SkipTrigger]

        init(
            _ name: String,
            options: FileOperationOptions.DirectoryTraversalOption = [],
            before: [SkipAction] = [],
            triggers: [SkipTrigger] = []
        ) {
            self.name = name
            self.options = options
            self.before = before
            self.triggers = triggers
        }

        var description: String { name }

    }


    /// The synchronous Skip suite's cases, one scenario each, all walked over the same tree.
    static let scenarios = [
        Scenario("skipDescendants of dir1", triggers: [.init(after: .entry("dir1", .directory), .skipDescendants)]),
        Scenario("skipDescendants of dir1/sub", triggers: [.init(after: .entry("dir1/sub", .directory), .skipDescendants)]),
        Scenario("skipDescendants of dir1/sub/sub2", triggers: [.init(after: .entry("dir1/sub/sub2", .directory), .skipDescendants)]),
        Scenario("skipDescendants of dir2", triggers: [.init(after: .entry("dir2", .directory), .skipDescendants)]),
        Scenario(
            "skipDescendants of dir1/sub and dir2",
            triggers: [
                .init(after: .entry("dir1/sub", .directory), .skipDescendants),
                .init(after: .entry("dir2", .directory), .skipDescendants)
            ]
        ),
        Scenario("skipDescendants after a file", triggers: [.init(after: .entry("a-file", .regular), .skipDescendants)]),
        Scenario("skipDescendants after a directory symlink", triggers: [.init(after: .entry("dir-link", .symlink), .skipDescendants)]),
        Scenario("skipDescendants after a leaving marker", triggers: [.init(after: .leavingDir("dir1/sub", nil), .skipDescendants)]),
        Scenario(
            "skipDescendants after dot entries",
            options: .includeDotEntries,
            triggers: [
                .init(after: .entry("dir1/.", .directory), .skipDescendants),
                .init(after: .entry("dir1/..", .directory), .skipDescendants)
            ]
        ),
        Scenario("skipDescendants before the first element", before: [.skipDescendants]),
        Scenario("skipCurrentDir after a file", triggers: [.init(after: .entry("dir1/sub/deep", .regular), .skipCurrentDir)]),
        Scenario("skipCurrentDir after a directory entry", triggers: [.init(after: .entry("dir1/sub", .directory), .skipCurrentDir)]),
        Scenario("skipCurrentDir after a leaving marker", triggers: [.init(after: .leavingDir("dir1/sub", nil), .skipCurrentDir)]),
        Scenario(
            "skipCurrentDir after a dot entry",
            options: .includeDotEntries,
            triggers: [.init(after: .entry("dir1/.", .directory), .skipCurrentDir)]
        ),
        Scenario("skipCurrentDir at the root level", triggers: [.init(after: .entry("a-file", .regular), .skipCurrentDir)]),
        Scenario("skipCurrentDir before the first element", before: [.skipCurrentDir]),
        Scenario(
            "skipCurrentDir overriding skipDescendants",
            triggers: [.init(after: .entry("dir1/sub", .directory), .skipDescendants, .skipCurrentDir)]
        ),
        Scenario(
            "skipDescendants after skipCurrentDir",
            triggers: [.init(after: .entry("dir1/sub", .directory), .skipCurrentDir, .skipDescendants)]
        )
    ]


    /// The same tree the synchronous Skip suite walks.
    func makeTree() throws -> FilePath {
        try workspace.makeFixture(
            at: "directory",
            [
                "a-file": .file(contents: "a"),
                "z-file": .file(contents: "z"),
                "file-link": .symlink(target: "a-file"),
                "dir-link": .symlink(target: "dir1"),
                "dir1": [
                    "f1": .file(contents: "f1"),
                    "g1": .file(contents: "g1"),
                    "sub": [
                        "deep": .file(contents: "deep"),
                        "sub2": [
                            "deeper": .file(contents: "deeper")
                        ]
                    ]
                ],
                "dir2": [
                    "f2": .file(contents: "f2")
                ]
            ]
        )
    }

}



extension AsyncRecursiveSequenceAPITests.SkipTests {

    // Batches of one to four elements put the boundaries of the skipped region at every position relative to
    // the batch boundaries; the default batch holds the whole tree, so every skip is resolved in the buffer.
    @Test(arguments: AsyncRecursiveSequenceAPITests.SkipTests.scenarios, [1, 2, 3, 4, 128])
    func `Yields the same elements as the synchronous iterator for any batch count`(
        scenario: Scenario,
        batchCount: Int
    ) async throws {

        let path = try makeTree()
        let expected = try AsyncRecursiveSequenceAPITests.runSync(
            DirectoryEntryRecursiveSequence(dirAt: path, options: scenario.options),
            before: scenario.before,
            triggers: scenario.triggers
        )

        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path, options: scenario.options, batchCount: batchCount)
        let elements = try await AsyncRecursiveSequenceAPITests.run(
            sequence,
            before: scenario.before,
            triggers: scenario.triggers
        )

        #expect(elements == expected)

    }


    @Test
    func `Ending the traversal by skipping the root keeps yielding nil`() async throws {

        let path = try makeTree()
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeAsyncIterator()

        let first = try await iterator.next()
        try #require(first != nil)
        iterator.skipCurrentDir()

        #expect(try await iterator.next() == nil)
        #expect(try await iterator.next() == nil)

    }


    // The cancellation check precedes the handling of skip requests.
    @Test
    func `Pre-cancelled next reports cancellation despite a pending skip request`() async throws {

        let path = try makeTree()
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        await Support.expectPreCancelled {
            var iterator = sequence.makeAsyncIterator()
            iterator.skipCurrentDir()
            return try await iterator.next()
        }

    }

}
