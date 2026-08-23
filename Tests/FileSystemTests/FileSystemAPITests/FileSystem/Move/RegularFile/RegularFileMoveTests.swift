import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MoveTests {

    @Suite("Regular file")
    struct RegularFileMoveTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MoveTests.RegularFileMoveTests {

    @Test
    func `Move to a new path preserves content, metadata, and identity`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "move contents")
        let dst = workspace.path("dst.txt")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .movedItem)
        try Support.expectItemNotExistNoFollow(at: src)

    }


    @Test
    func `Move into an existing subdirectory`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "move contents")
        try workspace.makeDirectory(at: "container")
        let dst = workspace.path("container/dst.txt")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.moveItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .movedItem)
        try Support.expectItemNotExistNoFollow(at: src)

    }


    @Test
    func `Moving one hard link preserves the shared file`() throws {

        let src = try workspace.makeFile(at: "link-a", contents: "shared contents")
        let sibling = workspace.path("link-b")
        // Foundation's `linkItem` creates a symlink on Windows; the library API is
        // independently covered by the Links group.
        try fileSystem.createHardLink(at: sibling, for: src)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dst = workspace.path("moved")

        try fileSystem.moveItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .movedItem)
        // The sibling still names the same file: same identity, same content.
        try Support.expectItem(at: sibling, matches: srcSnapshot, using: .hardLinkedItem)
        try Support.expectItemNotExistNoFollow(at: src)

    }

}
