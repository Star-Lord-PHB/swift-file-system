#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("BSD creation time")
    struct BSDCreationTimeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.BSDCreationTimeTests {

    private func shiftedTime(
        from timestamp: Support.ItemMetadata.Timestamp,
        by seconds: Int64
    ) -> FileTimeSpec {
        timestamp.adding(seconds: seconds).fileTimeSpec
    }


    private func expectCreationTime(
        _ actual: Support.ItemMetadata.Timestamp?,
        equals expected: Support.ItemMetadata.Timestamp?,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        Support.expectTimestampEquals(
            actual,
            expected,
            comment: "Creation time",
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
    func `Sets earlier creation and newer modification`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)
        guard let creationTimeBeforeSet = timesBeforeSet.creation else {
            try Test.cancel("Creation time is unavailable on this platform")
        }
        let requestedCreationTime = shiftedTime(
            from: creationTimeBeforeSet,
            by: -7_200
        )
        let requestedModificationTime = shiftedTime(
            from: creationTimeBeforeSet,
            by: -3_600
        )
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileTimes(
            modification: requestedModificationTime,
            creation: requestedCreationTime
        )

        try handle.close()

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        expectCreationTime(
            timesAfterSet.creation,
            equals: .init(fileTimeSpec: requestedCreationTime)
        )
        expectModificationTime(
            timesAfterSet.modification,
            equals: .init(fileTimeSpec: requestedModificationTime)
        )

    }


    @Test
    func `Earlier modification also moves creation`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)
        guard let creationTimeBeforeSet = timesBeforeSet.creation else {
            try Test.cancel("Creation time is unavailable on this platform")
        }
        let requestedModificationTime = shiftedTime(
            from: creationTimeBeforeSet,
            by: -3_600
        )
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileTimes(modification: requestedModificationTime)

        try handle.close()

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        expectCreationTime(
            timesAfterSet.creation,
            equals: .init(fileTimeSpec: requestedModificationTime)
        )
        expectModificationTime(
            timesAfterSet.modification,
            equals: .init(fileTimeSpec: requestedModificationTime)
        )

    }


    @Test
    func `Later creation request preserves creation but updates modification`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)
        guard let creationTimeBeforeSet = timesBeforeSet.creation else {
            try Test.cancel("Creation time is unavailable on this platform")
        }
        let requestedCreationTime = shiftedTime(
            from: creationTimeBeforeSet,
            by: 3_600
        )
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileTimes(creation: requestedCreationTime)

        try handle.close()

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        expectCreationTime(timesAfterSet.creation, equals: creationTimeBeforeSet)
        expectModificationTime(
            timesAfterSet.modification,
            equals: .init(fileTimeSpec: requestedCreationTime)
        )

    }

}

#endif
