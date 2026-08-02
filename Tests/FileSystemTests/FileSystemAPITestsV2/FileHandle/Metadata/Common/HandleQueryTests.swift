import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Query")
    struct QueryTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.QueryTests {

    @Test
    func `fileInfo matches path-based FileInfo`() throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let actual = try handle.fileInfo()
        let expected = try FileInfo(fileAt: path)

        #expect(actual == expected)

        try handle.close()

    }


    @Test
    func `type returns regular`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        #expect(try handle.type() == .regular)

        try handle.close()

    }


    @Test
    func `fileTimes matches independently captured times`() throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        let expected = try Support.ItemMetadata.Times.capture(at: path)

        let actual = try handle.fileTimes()

        Support.expectTimestampEquals(
            .init(fileTimeSpec: actual.lastAccess),
            expected.access,
            comment: "Access time"
        )
        Support.expectTimestampEquals(
            .init(fileTimeSpec: actual.lastModification),
            expected.modification,
            comment: "Modification time"
        )
        Support.expectTimestampEquals(
            .init(fileTimeSpec: actual.lastChange),
            expected.statusChange,
            comment: "Status-change time"
        )
        Support.expectTimestampEquals(
            actual.creation.map { .init(fileTimeSpec: $0) },
            expected.creation,
            comment: "Creation time"
        )

        try handle.close()

    }

}
