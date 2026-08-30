import Foundation
import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests {

    @Suite("Basic forwarding")
    struct BasicForwardingTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let fileSystem = FileSystem()
        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.BasicForwardingTests {

    @Test
    func `itemExists reports existing and missing items`() async throws {

        let existing = try workspace.makeFile(at: "file")
        let missing = workspace.path("missing")

        #expect(await asyncFileSystem.itemExists(at: existing))
        #expect(await asyncFileSystem.itemExists(at: missing) == false)

    }


    @Test
    func `itemExists forwards the follow-symlinks option`() async throws {

        let missingTarget = workspace.path("missing-target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: missingTarget)

        #expect(await asyncFileSystem.itemExists(at: link, followSymlinks: false))
        #expect(await asyncFileSystem.itemExists(at: link) == false)

    }


    @Test
    func `createFile forwards content and the replace option`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "old content")
        let newContent = ByteBuffer("new content".utf8)

        try await asyncFileSystem.createFile(at: path, replaceExisting: true, content: newContent)

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("new content".utf8))

    }


    @Test
    func `createFile passes through the existing-item error`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "old content")

        let error = await #expect(throws: PlatformError.self) {
            try await asyncFileSystem.createFile(at: path)
        }

        #expect(error?.kind == .alreadyExists)
        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("old content".utf8))

    }


    @Test
    func `createDirectory forwards the intermediate-directories option`() async throws {

        let path = workspace.path("parent/nested/leaf")

        try await asyncFileSystem.createDirectory(at: path, withIntermediateDirectories: true)

        #expect(try Support.ItemMetadata.capture(at: path).type == .typeDirectory)

    }


    @Test
    func `moveItem forwards source and destination paths`() async throws {

        let source = try workspace.makeFile(at: "source", contents: "move contents")
        let destination = workspace.path("destination")

        try await asyncFileSystem.moveItem(at: source, to: destination)

        try Support.expectItemNotExistNoFollow(at: source)
        #expect(try Data(contentsOf: URL(filePath: destination.string)) == Data("move contents".utf8))

    }


    @Test
    func `moveItem forwards the existing-target option`() async throws {

        let source = try workspace.makeFile(at: "source", contents: "source contents")
        let destination = try workspace.makeFile(at: "destination", contents: "destination contents")

        let error = await #expect(throws: PlatformError.self) {
            try await asyncFileSystem.moveItem(at: source, to: destination, onExistingTarget: .error)
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectItemExistNoFollow(at: source)

    }


    @Test
    func `contentsOfDirectory forwards the dot-entries option`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ],
            ]
        )

        let entries = try await asyncFileSystem.contentsOfDirectory(
            at: path,
            options: [.includeDotEntries]
        )

        let expected = try fileSystem.contentsOfDirectory(at: path, options: [.includeDotEntries])
        let defaultEntries = try fileSystem.contentsOfDirectory(at: path)
        #expect(Set(entries) == Set(expected))
        #expect(Set(entries) != Set(defaultEntries))

    }


    @Test
    func `createSymLink forwards link and destination paths`() async throws {

        let storedTarget = workspace.path("missing-target")
        let link = workspace.path("link")

        try await asyncFileSystem.createSymLink(at: link, pointingTo: storedTarget)

        #expect(try fileSystem.destinationOfSymLink(at: link, recursive: false) == storedTarget)

    }


    @Test
    func `createHardLink forwards link and existing paths`() async throws {

        let existing = try workspace.makeFile(at: "existing", contents: "hard-link contents")
        let link = workspace.path("link")

        try await asyncFileSystem.createHardLink(at: link, for: existing)

        let linkIdentifier = try Support.ItemMetadata.captureIdentifier(at: link)
        let existingIdentifier = try Support.ItemMetadata.captureIdentifier(at: existing)
        #expect(linkIdentifier == existingIdentifier)

    }


    @Test
    func `destinationOfSymLink forwards the recursive option`() async throws {

        let target = try workspace.makeFile(at: "target")
        let intermediate = try workspace.makeSymlink(at: "intermediate", pointingTo: target)
        let link = try workspace.makeSymlink(at: "link", pointingTo: intermediate)

        let directDestination = try await asyncFileSystem
            .destinationOfSymLink(at: link, recursive: false)
        let resolvedDestination = try await asyncFileSystem
            .destinationOfSymLink(at: link, recursive: true)

        let expectedResolution = try fileSystem.destinationOfSymLink(at: link, recursive: true)
        #expect(directDestination == intermediate)
        #expect(resolvedDestination == expectedResolution)

    }

}
