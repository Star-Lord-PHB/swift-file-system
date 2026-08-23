import Foundation
import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Creation")
    struct CreationTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CreationTests {

    private var noReplacementPolicy: Support.ItemComparisonPolicy {
        .init(fields: [.logicalContents, .fileIdentifier])
    }


    @Test
    func `Creates an empty file`() throws {

        let path = workspace.path("file")

        try fileSystem.createFile(at: path)

        let metadata = try Support.ItemMetadata.capture(at: path)
        #expect(metadata.type == .typeRegular)
        #expect(metadata.size == 0)
        #expect(try Data(contentsOf: URL(filePath: path.string)).isEmpty)

    }


    @Test
    func `Creates a file with content`() throws {

        let path = workspace.path("file")
        let content = ByteBuffer("Hello, Swift!".utf8)

        try fileSystem.createFile(at: path, content: content)

        let metadata = try Support.ItemMetadata.capture(at: path)
        #expect(metadata.type == .typeRegular)
        #expect(metadata.size == UInt64(content.count))
        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data(content))

    }


    @Test
    func `Replace option creates missing file`() throws {

        let path = workspace.path("file")
        let content = ByteBuffer("new content".utf8)

        try fileSystem.createFile(
            at: path,
            replaceExisting: true,
            content: content
        )

        let metadata = try Support.ItemMetadata.capture(at: path)
        #expect(metadata.type == .typeRegular)
        #expect(metadata.size == UInt64(content.count))
        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data(content))

    }


    @Test
    func `Replace truncates existing file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "old content")

        try fileSystem.createFile(at: path, replaceExisting: true)

        let metadata = try Support.ItemMetadata.capture(at: path)
        #expect(metadata.type == .typeRegular)
        #expect(metadata.size == 0)
        #expect(try Data(contentsOf: URL(filePath: path.string)).isEmpty)

    }


    @Test
    func `Replace writes new file content`() throws {

        let path = try workspace.makeFile(at: "file", contents: "old content")
        let newContent = ByteBuffer("new content".utf8)

        try fileSystem.createFile(at: path, replaceExisting: true, content: newContent)

        let metadata = try Support.ItemMetadata.capture(at: path)
        #expect(metadata.type == .typeRegular)
        #expect(metadata.size == UInt64(newContent.count))
        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data(newContent))

    }


    @Test
    func `Replacing a directory with a file fails and preserves the directory`() throws {

        let directory = try workspace.makeDirectory(at: "directory")
        let child = try workspace.makeFile(
            at: "directory/child",
            contents: "existing contents"
        )
        let directorySnapshot = try Support.ItemSnapshot.capture(at: directory)
        let childSnapshot = try Support.ItemSnapshot.capture(at: child)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createFile(
                at: directory,
                replaceExisting: true,
                content: ByteBuffer("replacement content".utf8)
            )
        }

        #expect(error?.kind.maybe(.isADirectory) == true)
        try Support.expectItem(at: directory, matches: directorySnapshot, using: noReplacementPolicy)
        try Support.expectItem(at: child, matches: childSnapshot, using: noReplacementPolicy)

    }


    @Test
    func `No-replace creation fails and preserves existing file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "original content")
        let snapshot = try Support.ItemSnapshot.capture(at: path)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createFile(
                at: path,
                content: ByteBuffer("replacement content".utf8)
            )
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectItem(at: path, matches: snapshot, using: noReplacementPolicy)

    }


    @Test
    func `File creation fails when parent is missing`() throws {

        let parent = workspace.path("missing-parent")
        let path = workspace.path("missing-parent/file")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createFile(at: path)
        }

        #expect(error?.kind == .notFound)
        #expect(!fileSystem.itemExists(at: parent))
        #expect(!fileSystem.itemExists(at: path))

    }


    @Test
    func `Creates a directory`() throws {

        let path = workspace.path("directory")

        try fileSystem.createDirectory(at: path)

        #expect(try Support.ItemMetadata.capture(at: path).type == .typeDirectory)

    }


    @Test
    func `Directory creation fails when parent is missing`() throws {

        let parent = workspace.path("missing-parent")
        let path = workspace.path("missing-parent/directory")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createDirectory(at: path)
        }

        #expect(error?.kind == .notFound)
        #expect(!fileSystem.itemExists(at: parent))
        #expect(!fileSystem.itemExists(at: path))

    }


    @Test
    func `Directory creation without intermediates fails and preserves existing dir`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let snapshot = try Support.ItemSnapshot.capture(at: path)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createDirectory(at: path)
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectItem(at: path, matches: snapshot, using: noReplacementPolicy)

    }


    @Test
    func `Creates missing intermediate dirs`() throws {

        let first = workspace.path("a")
        let second = workspace.path("a/b")
        let leaf = workspace.path("a/b/c")

        try fileSystem.createDirectory(
            at: leaf,
            withIntermediateDirectories: true
        )

        #expect(try Support.ItemMetadata.capture(at: first).type == .typeDirectory)
        #expect(try Support.ItemMetadata.capture(at: second).type == .typeDirectory)
        #expect(try Support.ItemMetadata.capture(at: leaf).type == .typeDirectory)

    }


    @Test
    func `Directory creation with intermediates is a no-op for existing dir`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let snapshot = try Support.ItemSnapshot.capture(at: path)

        try fileSystem.createDirectory(
            at: path,
            withIntermediateDirectories: true
        )

        try Support.expectItem(at: path, matches: snapshot, using: noReplacementPolicy)

    }


    @Test
    func `Directory creation with intermediates fails for existing file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "original content")
        let snapshot = try Support.ItemSnapshot.capture(at: path)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.createDirectory(
                at: path,
                withIntermediateDirectories: true
            )
        }

        #expect(error?.kind == .alreadyExists)
        try Support.expectItem(at: path, matches: snapshot, using: noReplacementPolicy)

    }

}
