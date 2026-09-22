import SystemPackage
import Testing
import SwiftFileSystem



extension RecursiveSequenceAPITests {

    @Suite("Skip")
    struct SkipTests {

        typealias Support = RecursiveSequenceAPITests.Support
        typealias ElementShape = RecursiveSequenceAPITests.ElementShape
        typealias SkipAction = RecursiveSequenceAPITests.SkipAction
        typealias SkipTrigger = RecursiveSequenceAPITests.SkipTrigger

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension RecursiveSequenceAPITests.SkipTests {

    /// The tree every test walks: a root-level directory with files and a nested pair of directories, a second
    /// root-level directory, and root-level files and symlinks (`dir-link` points at a directory and is never
    /// entered).
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


    func run(
        _ sequence: DirectoryEntryRecursiveSequence,
        before: [SkipAction] = [],
        triggers: [SkipTrigger] = [],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> RecursiveSequenceAPITests.Traversal {
        try RecursiveSequenceAPITests.run(sequence, before: before, triggers: triggers, sourceLocation: sourceLocation)
    }

}



extension RecursiveSequenceAPITests.SkipTests {

    // A root-level directory, a nested one, the deepest one, and one whose position among its siblings makes it
    // the last entry of its directory on some file systems, in which case the element after the skipped entry is
    // the parent's leaving marker.
    @Test(arguments: ["dir1", "dir1/sub", "dir1/sub/sub2", "dir2"] as [FilePath])
    func `Skipping descendants removes the region of the directory and its marker`(dir: FilePath) throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)
        let expected = try baseline.removingRegion(of: dir)

        let elements = try run(sequence, triggers: [.init(after: .entry(dir, .directory), .skipDescendants)])

        #expect(elements == expected)
        #expect(!elements.contains { $0.path.starts(with: dir) && $0.path != dir })

    }


    @Test
    func `Skipping descendants of two directories removes both regions`() throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)
        let expected = try baseline.removingRegion(of: "dir1/sub").removingRegion(of: "dir2")

        let elements = try run(
            sequence,
            triggers: [
                .init(after: .entry("dir1/sub", .directory), .skipDescendants),
                .init(after: .entry("dir2", .directory), .skipDescendants)
            ]
        )

        #expect(elements == expected)

    }


    // A file, a symlink to a directory (never entered) and a leaving marker: none of them has descendants.
    @Test(arguments: [
        .entry("a-file", .regular),
        .entry("dir-link", .symlink),
        .leavingDir("dir1/sub", nil)
    ] as [RecursiveSequenceAPITests.ElementShape])
    func `Skipping descendants after an element without descendants has no effect`(trigger: ElementShape) throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)

        let elements = try run(sequence, triggers: [.init(after: trigger, .skipDescendants)])

        #expect(elements == baseline)

    }


    // Dot entries carry the directory kind but are never entered. They are listed ahead of the regular entries
    // on the supported file systems, so a request that leaked past them would skip the directory that follows.
    @Test
    func `Skipping descendants after a dot entry has no effect`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "parent": [
                    "child": [
                        "file": .file(contents: "contents")
                    ]
                ]
            ]
        )
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path, options: .includeDotEntries)
        let baseline = try run(sequence)

        let elements = try run(
            sequence,
            triggers: [
                .init(after: .entry("parent/.", .directory), .skipDescendants),
                .init(after: .entry("parent/..", .directory), .skipDescendants)
            ]
        )

        #expect(elements == baseline)
        #expect(elements.contains(.entry("parent/child/file", .regular)))

    }


    @Test
    func `Skipping descendants before the first element has no effect`() throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)

        let elements = try run(sequence, before: [.skipDescendants])

        #expect(elements == baseline)

    }


    @Test
    func `Skipping the current directory after a file leaves it immediately`() throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)
        let trigger = ElementShape.entry("dir1/sub/deep", .regular)
        let expected = try baseline.leavingEarly(after: trigger, dir: "dir1/sub")

        let elements = try run(sequence, triggers: [.init(after: trigger, .skipCurrentDir)])

        #expect(elements == expected)

    }


    @Test
    func `Skipping the current directory after a directory entry skips it and leaves the parent`() throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)
        let trigger = ElementShape.entry("dir1/sub", .directory)
        let expected = try baseline.leavingEarly(after: trigger, dir: "dir1")

        let elements = try run(sequence, triggers: [.init(after: trigger, .skipCurrentDir)])

        #expect(elements == expected)
        #expect(!elements.contains { $0.path.starts(with: "dir1/sub") && $0.path != "dir1/sub" })

    }


    @Test
    func `Skipping the current directory after a leaving marker leaves the parent`() throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)
        let trigger = ElementShape.leavingDir("dir1/sub", nil)
        let expected = try baseline.leavingEarly(after: trigger, dir: "dir1")

        let elements = try run(sequence, triggers: [.init(after: trigger, .skipCurrentDir)])

        #expect(elements == expected)

    }


    @Test
    func `Skipping the current directory after a dot entry leaves the directory holding it`() throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path, options: .includeDotEntries)
        let baseline = try run(sequence)
        let trigger = ElementShape.entry("dir1/.", .directory)
        let expected = try baseline.leavingEarly(after: trigger, dir: "dir1")

        let elements = try run(sequence, triggers: [.init(after: trigger, .skipCurrentDir)])

        #expect(elements == expected)

    }


    @Test
    func `Skipping the current directory at the root level ends the traversal`() throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)
        let trigger = ElementShape.entry("a-file", .regular)
        let expected = try baseline.ending(after: trigger)

        let elements = try run(sequence, triggers: [.init(after: trigger, .skipCurrentDir)])

        #expect(elements == expected)

    }


    @Test
    func `Skipping the current directory before the first element ends the traversal`() throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)

        let elements = try run(sequence, before: [.skipCurrentDir])

        #expect(elements.isEmpty)

    }


    @Test(arguments: [
        [.skipDescendants, .skipCurrentDir],
        [.skipCurrentDir, .skipDescendants]
    ] as [[RecursiveSequenceAPITests.SkipAction]])
    func `Skipping the current directory overrides skipping descendants`(actions: [SkipAction]) throws {

        let path = try makeTree()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let baseline = try run(sequence)
        let trigger = ElementShape.entry("dir1/sub", .directory)
        let expected = try baseline.leavingEarly(after: trigger, dir: "dir1")

        let elements = try run(sequence, triggers: [.init(after: trigger, actions: actions)])

        #expect(elements == expected)

    }

}
