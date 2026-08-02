import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("All handle types")
    struct AllHandleTypeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.AllHandleTypeTests {

    // NOTE: The metadata APIs share one implementation across all handle kinds, so each
    // kind only gets a representative query and, for write-capable handles, a
    // representative setter. Metadata setters through read-only and directory handles
    // diverge by platform; see the POSIX and Windows non-writable handle setter suites.

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
    func `ReadFileHandle fileInfo matches path-based FileInfo`() throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try ReadFileHandle(forFileAt: path)

        #expect(try handle.fileInfo() == FileInfo(fileAt: path))

        try handle.close()

    }


    @Test
    func `WriteFileHandle fileInfo matches path-based FileInfo`() throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try WriteFileHandle(forFileAt: path)

        #expect(try handle.fileInfo() == FileInfo(fileAt: path))

        try handle.close()

    }


    @Test
    func `AppendHandle fileInfo matches path-based FileInfo`() throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try AppendHandle(forFileAt: path)

        #expect(try handle.fileInfo() == FileInfo(fileAt: path))

        try handle.close()

    }


    @Test
    func `DirectoryHandle fileInfo matches path-based FileInfo`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let handle = try DirectoryHandle(forDirAt: path)

        #expect(try handle.fileInfo() == FileInfo(fileAt: path))
        #expect(try handle.type() == .directory)

        try handle.close()

    }


    @Test
    func `WriteFileHandle sets file times`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try WriteFileHandle(forFileAt: path)

        try handle.setFileTimes(
            access: sampleAccessTime,
            modification: sampleModificationTime
        )

        try handle.close()

        try expectSampleTimes(at: path)

    }


    @Test
    func `AppendHandle sets file times`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try AppendHandle(forFileAt: path)

        try handle.setFileTimes(
            access: sampleAccessTime,
            modification: sampleModificationTime
        )

        try handle.close()

        try expectSampleTimes(at: path)

    }

}
