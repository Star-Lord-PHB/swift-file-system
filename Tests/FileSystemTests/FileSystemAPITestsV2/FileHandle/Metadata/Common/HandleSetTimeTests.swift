import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Set times")
    struct SetTimeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.SetTimeTests {

    private var sampleAccessTime: FileTimeSpec {
        .init(seconds: 1_706_745_678, nanoseconds: 123_456_700)
    }


    private var sampleModificationTime: FileTimeSpec {
        .init(seconds: 1_696_543_210, nanoseconds: 234_567_800)
    }


    private func expectAccessTime(
        _ actual: Support.ItemMetadata.Timestamp,
        equals expected: Support.ItemMetadata.Timestamp,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        Support.expectTimestampEquals(
            actual,
            expected,
            comment: "Access time",
            sourceLocation: sourceLocation
        )
    }


    private func expectModificationTime(
        _ actual: Support.ItemMetadata.Timestamp,
        equals expected: Support.ItemMetadata.Timestamp,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        Support.expectTimestampEquals(
            actual,
            expected,
            comment: "Modification time",
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `Sets access and modification times`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileTimes(
            access: sampleAccessTime,
            modification: sampleModificationTime
        )

        try handle.close()

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        expectAccessTime(
            timesAfterSet.access,
            equals: .init(fileTimeSpec: sampleAccessTime)
        )
        expectModificationTime(
            timesAfterSet.modification,
            equals: .init(fileTimeSpec: sampleModificationTime)
        )

    }


    @Test
    func `Omitted times remain unchanged`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)

        let modificationHandle = try ReadWriteFileHandle(forFileAt: path)
        try modificationHandle.setFileTimes(modification: sampleModificationTime)
        try modificationHandle.close()

        let timesAfterModificationSet = try Support.ItemMetadata.Times.capture(at: path)
        expectAccessTime(timesAfterModificationSet.access, equals: timesBeforeSet.access)
        expectModificationTime(
            timesAfterModificationSet.modification,
            equals: .init(fileTimeSpec: sampleModificationTime)
        )

        let accessHandle = try ReadWriteFileHandle(forFileAt: path)
        try accessHandle.setFileTimes(access: sampleAccessTime)
        try accessHandle.close()

        let timesAfterAccessSet = try Support.ItemMetadata.Times.capture(at: path)
        expectAccessTime(
            timesAfterAccessSet.access,
            equals: .init(fileTimeSpec: sampleAccessTime)
        )
        expectModificationTime(
            timesAfterAccessSet.modification,
            equals: timesAfterModificationSet.modification
        )

    }


    @Test
    func `All nil times leave metadata unchanged`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)

        let handle = try ReadWriteFileHandle(forFileAt: path)
        try handle.setFileTimes()
        try handle.close()

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        #expect(timesAfterSet == timesBeforeSet)

    }

}
