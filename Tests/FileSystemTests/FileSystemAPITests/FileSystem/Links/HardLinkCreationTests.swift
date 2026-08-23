import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Hard-link creation")
    struct HardLinkCreationTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.HardLinkCreationTests {

    @Test
    func `Creates a hard link to a regular file`() throws {

        let existing = try workspace.makeFile(at: "existing", contents: "contents")
        let existingSnapshot = try Support.ItemSnapshot.capture(at: existing)
        let link = workspace.path("link")

        try fileSystem.createHardLink(at: link, for: existing)

        try Support.expectItem(
            at: link,
            matches: existingSnapshot,
            using: .hardLinkedItem
        )

    }


    @Test
    func `Creates a hard link to a symlink itself`() throws {

        let existing = try workspace.makeSymlink(
            at: "existing",
            pointingTo: workspace.path("missing-target")
        )
        let existingSnapshot = try Support.ItemSnapshot.capture(at: existing)
        let link = workspace.path("link")

        try fileSystem.createHardLink(at: link, for: existing)

        try Support.expectItem(
            at: link,
            matches: existingSnapshot,
            using: .hardLinkedItem
        )

    }


    @Test
    func `Hard-linking a directory fails`() throws {

        let existing = try workspace.makeDirectory(at: "directory")
        let existingSnapshot = try Support.ItemSnapshot.capture(at: existing)
        let link = workspace.path("link")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createHardLink(at: link, for: existing)
        }

        #expect(error?.kind == .permissionDenied)
        try Support.expectItemNotExistNoFollow(at: link)
        try Support.expectItem(at: existing, matches: existingSnapshot, using: .unchanged)

    }


    @Test
    func `Creation fails when existing item is missing`() throws {

        let existing = workspace.path("missing")
        let link = workspace.path("link")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createHardLink(at: link, for: existing)
        }

        #expect(error?.kind == .notFound)
        try Support.expectItemNotExistNoFollow(at: link)

    }


    @Test
    func `Creation fails and preserves existing destination`() throws {

        let existing = try workspace.makeFile(
            at: "original",
            contents: "original file data"
        )
        let occupiedPath = try workspace.makeFile(
            at: "occupied",
            contents: "unrelated file data"
        )
        let existingSnapshot = try Support.ItemSnapshot.capture(at: existing)
        let occupiedSnapshot = try Support.ItemSnapshot.capture(at: occupiedPath)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createHardLink(at: occupiedPath, for: existing)
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectItem(at: existing, matches: existingSnapshot, using: .unchanged)
        try Support.expectItem(at: occupiedPath, matches: occupiedSnapshot, using: .unchanged)

    }


    @Test
    func `Creation fails when parent is missing`() throws {

        let existing = try workspace.makeFile(at: "existing", contents: "contents")
        let parent = workspace.path("missing-parent")
        let link = workspace.path("missing-parent/link")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createHardLink(at: link, for: existing)
        }

        #expect(error?.kind == .notFound)
        try Support.expectItemNotExistNoFollow(at: parent)
        try Support.expectItemNotExistNoFollow(at: link)

    }

}
