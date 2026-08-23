import Testing
import SwiftFileSystem



extension FileHandleAPITests.DirectoryTests {

    @Test
    func `Recursive entry sequence visits the complete tree`() throws {

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
        let handle = try DirectoryHandle(forDirAt: path)

        let elements: [DirectoryEntryRecursiveSequenceElement]
        do {
            let sequence = handle.entryRecursiveSequence()
            elements = try sequence.map { result in
                try result.get()
            }
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
    func `Recursive skip-dir hides directory markers but still visits descendants`() throws {

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
        let handle = try DirectoryHandle(forDirAt: path)

        let elements: [DirectoryEntryRecursiveSequenceElement]
        do {
            let sequence = handle.entryRecursiveSequence(options: .skipDir)
            elements = try sequence.map { result in
                try result.get()
            }
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
    func `Recursive entry sequence can include dot entries`() throws {

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

        let elements: [DirectoryEntryRecursiveSequenceElement]
        do {
            let sequence = handle.entryRecursiveSequence(options: .includeDotEntries)
            elements = try sequence.map { result in
                try result.get()
            }
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
    func `Recursive entry sequence traverses a directory symlink target`() throws {

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
        let handle = try DirectoryHandle(forDirAt: link)

        let elements: [DirectoryEntryRecursiveSequenceElement]
        do {
            let sequence = handle.entryRecursiveSequence()
            elements = try sequence.map { result in
                try result.get()
            }
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

}
