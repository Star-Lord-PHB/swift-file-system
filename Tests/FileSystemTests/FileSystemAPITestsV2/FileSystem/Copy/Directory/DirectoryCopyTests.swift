import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Directory")
    struct DirectoryCopyTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.DirectoryCopyTests {

    @Test
    func `Copies a tree with contents and metadata`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "file contents"),
                "link": .symlink(target: "file.txt"),
                "dangling": .symlink(target: "missing"),
                "empty": [:],
                "sub": [
                    "nested.txt": .file(contents: "nested contents"),
                    "inner-link": .symlink(target: "../file.txt"),
                ],
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)
        // The copy reads the source, which pushes access times on volumes that maintain them.
        try Support.expectTree(at: src, matches: srcSnapshot, using: .unchanged.excluding(.accessTime))

    }


    @Test
    func `Copies an empty directory`() throws {

        let src = try workspace.makeDirectory(at: "src")
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `Copies a deeply nested tree`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "l1": [
                    "l2": [
                        "l3": [
                            "l4": [
                                "leaf.txt": .file(contents: "leaf contents")
                            ]
                        ]
                    ]
                ]
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test(arguments: [.overwrite, .skip, .error] as [FileOperationOptions.CopyTargetExistOption])
    func `Copies to a missing destination regardless of existing-target option`(
        option: FileOperationOptions.CopyTargetExistOption
    ) throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "file contents"),
                "sub": [
                    "nested.txt": .file(contents: "nested contents")
                ],
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: option))

        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)

    }

}
