import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("All handle types")
    struct AllHandleTypeTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The metadata APIs share one implementation across all async handle kinds and views;
// what differs per kind is the `withUnsafeSystemHandle` plumbing into the executor (each
// handle's own, and the views' delegation to the positional accessor), so each kind gets a
// representative query and, for write-capable kinds, a representative setter. Setters
// through read-only handles diverge by platform in the synchronous layer and are not
// re-tested here. `SwiftFileSystem` is imported for the path-based `FileInfo` oracle only.
extension AsyncFileHandleAPITests.MetadataTests.AllHandleTypeTests {

    private var sampleAccessTime: FileTimeSpec {
        .init(seconds: 1_706_745_678, nanoseconds: 123_456_700)
    }


    private var sampleModificationTime: FileTimeSpec {
        .init(seconds: 1_696_543_210, nanoseconds: 234_567_800)
    }


    private func expectSampleTimes(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let timesAfterSet = try Support.ItemMetadata.Times.capture(
            at: path,
            sourceLocation: sourceLocation
        )
        Support.expectTimestampEquals(
            timesAfterSet.access,
            .init(fileTimeSpec: sampleAccessTime),
            comment: "Access time",
            sourceLocation: sourceLocation
        )
        Support.expectTimestampEquals(
            timesAfterSet.modification,
            .init(fileTimeSpec: sampleModificationTime),
            comment: "Modification time",
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `AsyncReadFileHandle fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        #expect(try await handle.fileInfo() == FileInfo(fileAt: path))

        try await handle.close()

    }


    @Test
    func `AsyncWriteFileHandle fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        #expect(try await handle.fileInfo() == FileInfo(fileAt: path))

        try await handle.close()

    }


    @Test
    func `AsyncReadWriteFileHandle fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        #expect(try await handle.fileInfo() == FileInfo(fileAt: path))

        try await handle.close()

    }


    @Test
    func `AsyncAppendHandle fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncAppendHandle(forFileAt: path)

        #expect(try await handle.fileInfo() == FileInfo(fileAt: path))

        try await handle.close()

    }


    @Test
    func `AsyncStreamingReadHandle fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncStreamingReadHandle(forFileAt: path)

        #expect(try await handle.fileInfo() == FileInfo(fileAt: path))

        try await handle.close()

    }


    @Test
    func `AsyncStreamingWriteHandle fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncStreamingWriteHandle(forFileAt: path)

        #expect(try await handle.fileInfo() == FileInfo(fileAt: path))

        try await handle.close()

    }


    @Test
    func `AsyncStreamingReadWriteHandle fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncStreamingReadWriteHandle(forFileAt: path)

        #expect(try await handle.fileInfo() == FileInfo(fileAt: path))

        try await handle.close()

    }


    @Test
    func `AsyncDirectoryHandle fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeDirectory(at: "directory")
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        #expect(try await handle.fileInfo() == FileInfo(fileAt: path))

        try await handle.close()

    }


    @Test
    func `SequentialReader fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        let reader = handle.sequentialReader()

        #expect(try await reader.fileInfo() == FileInfo(fileAt: path))

    }


    @Test
    func `SequentialWriter fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        let writer = handle.sequentialWriter()

        #expect(try await writer.fileInfo() == FileInfo(fileAt: path))

    }


    @Test
    func `SequentialAccessor fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        let accessor = handle.sequentialAccessor()

        #expect(try await accessor.fileInfo() == FileInfo(fileAt: path))

    }


    @Test
    func `AsyncWriteFileHandle sets file times`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        try await handle.setFileTimes(access: sampleAccessTime, modification: sampleModificationTime)

        try await handle.close()

        try expectSampleTimes(at: path)

    }


    @Test
    func `AsyncAppendHandle sets file times`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncAppendHandle(forFileAt: path)

        try await handle.setFileTimes(access: sampleAccessTime, modification: sampleModificationTime)

        try await handle.close()

        try expectSampleTimes(at: path)

    }


    @Test
    func `AsyncStreamingWriteHandle sets file times`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncStreamingWriteHandle(forFileAt: path)

        try await handle.setFileTimes(access: sampleAccessTime, modification: sampleModificationTime)

        try await handle.close()

        try expectSampleTimes(at: path)

    }


    @Test
    func `SequentialWriter sets file times`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)
        let writer = handle.sequentialWriter()

        try await writer.setFileTimes(access: sampleAccessTime, modification: sampleModificationTime)

        try expectSampleTimes(at: path)

    }

}
