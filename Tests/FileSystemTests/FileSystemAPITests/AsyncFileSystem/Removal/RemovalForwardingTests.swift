import Foundation
import Testing
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests.RemovalTests {

    /// The root reaches the handler, slicing is invisible in the result, and the session's error
    /// is what the caller gets.
    @Suite("Forwarding")
    struct RemovalForwardingTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.RemovalTests.RemovalForwardingTests {

    @Test
    func `Removes a tree without following its symlinks`() async throws {

        let fileTarget = try workspace.makeFile(at: "file-target", contents: "file target contents")
        let dirTarget = try workspace.makeFixture(
            at: "dir-target",
            [
                "file": .file(contents: "dir target contents")
            ]
        )
        let root = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                ".hidden": .file(contents: "hidden contents"),
                "file-link": .symlink(target: fileTarget),
                "sub": [
                    "nested": .file(contents: "nested contents"),
                    "dir-link": .symlink(target: dirTarget),
                ],
            ]
        )
        let fileTargetSnapshot = try Support.ItemSnapshot.capture(at: fileTarget)
        let dirTargetSnapshot = try Support.TreeSnapshot.capture(at: dirTarget)

        try await asyncFileSystem.removeItem(at: root)

        try Support.expectItemNotExistNoFollow(at: root)
        try Support.expectItem(at: fileTarget, matches: fileTargetSnapshot, using: .unchanged)
        try Support.expectTree(at: dirTarget, matches: dirTargetSnapshot, using: .unchanged)

    }


    @Test
    func `Removes a large tree across time slices`() async throws {

        // Far more entries than one time slice removes on any platform measured, so the session
        // is resumed across several executor jobs; the slice boundaries must be invisible in the
        // result. The tree is built with plain string paths: the workspace helpers pay for a
        // `FilePath` resolution per file, which dominates at this count in a debug build.
        let root = workspace.path("directory")
        for directoryIndex in 0..<10 {
            let directory = root.appending("dir-\(directoryIndex)").string
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            for fileIndex in 0..<100 {
                let created = FileManager.default.createFile(
                    atPath: "\(directory)/file-\(fileIndex)",
                    contents: Data("\(directoryIndex)/\(fileIndex)".utf8)
                )
                try #require(created)
            }
        }

        try await asyncFileSystem.removeItem(at: root)

        try Support.expectItemNotExistNoFollow(at: root)

    }


    @Test
    func `Missing root throws not found`() async throws {

        let path = workspace.path("missing")

        let error = await #expect(throws: PlatformError.self) {
            try await asyncFileSystem.removeItem(at: path)
        }

        #expect(error?.kind == .notFound)
        #expect(error?.operation == .remove(path))

    }

}
