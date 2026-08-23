import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Symbolic-link creation")
    struct SymbolicLinkCreationTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.SymbolicLinkCreationTests {

    private var followedTargetPolicy: Support.ItemComparisonPolicy {
        .init(fields: [.logicalContents, .fileIdentifier])
    }


    private func expectSymbolicLink(
        at path: FilePath,
        stores target: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let storedTarget = try FileManager.default.destinationOfSymbolicLink(
            atPath: path.string
        )
        #expect(FilePath(storedTarget) == target, sourceLocation: sourceLocation)
    }


    @Test
    func `Creates an absolute symlink to a file`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let targetSnapshot = try Support.ItemSnapshot.capture(at: target)
        let link = workspace.path("link")

        try fileSystem.createSymLink(at: link, pointingTo: target)

        try expectSymbolicLink(at: link, stores: target)
        try Support.expectItem(
            at: link,
            matches: targetSnapshot,
            using: followedTargetPolicy,
            followSymlink: true
        )

    }


    @Test
    func `Creates a relative symlink to a directory`() throws {

        let target = try workspace.makeFixture(
            at: "container/target",
            [
                "file": .file(contents: "target contents")
            ]
        )
        let targetSnapshot = try Support.ItemSnapshot.capture(at: target)
        let storedTarget = FilePath("target")
        let link = workspace.path("container/link")

        try fileSystem.createSymLink(at: link, pointingTo: storedTarget)

        try expectSymbolicLink(at: link, stores: storedTarget)
        try Support.expectItem(
            at: link,
            matches: targetSnapshot,
            using: followedTargetPolicy,
            followSymlink: true
        )

    }


    @Test
    func `Creates a symlink to another symlink`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let targetLink = try workspace.makeSymlink(
            at: "target-link",
            pointingTo: target
        )
        let targetSnapshot = try Support.ItemSnapshot.capture(at: target)
        let link = workspace.path("link")

        try fileSystem.createSymLink(at: link, pointingTo: targetLink)

        try expectSymbolicLink(at: link, stores: targetLink)
        try Support.expectItem(
            at: link,
            matches: targetSnapshot,
            using: followedTargetPolicy,
            followSymlink: true
        )

    }


    @Test
    func `Creates a dangling symlink`() throws {

        let missingTarget = workspace.path("missing-target")
        let link = workspace.path("link")

        try fileSystem.createSymLink(at: link, pointingTo: missingTarget)

        try expectSymbolicLink(at: link, stores: missingTarget)

    }


    @Test
    func `Creation fails and preserves an existing item`() throws {

        let target = try workspace.makeFile(at: "target")
        let occupiedPath = try workspace.makeFile(at: "occupied", contents: "existing contents")
        let occupiedSnapshot = try Support.ItemSnapshot.capture(at: occupiedPath)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createSymLink(at: occupiedPath, pointingTo: target)
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectItem(at: occupiedPath, matches: occupiedSnapshot, using: .unchanged)

    }


    @Test
    func `Creation fails when parent is missing`() throws {

        try workspace.makeFile(at: "target")
        let parent = workspace.path("missing-parent")
        let link = workspace.path("missing-parent/link")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createSymLink(at: link, pointingTo: "../target")
        }

        #expect(error?.kind == .notFound)
        try Support.expectItemNotExistNoFollow(at: parent)
        try Support.expectItemNotExistNoFollow(at: link)

    }

}
