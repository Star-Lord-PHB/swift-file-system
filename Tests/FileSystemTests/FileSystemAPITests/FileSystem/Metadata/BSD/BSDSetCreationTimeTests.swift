#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("BSD creation time setting")
    struct BSDSetCreationTimeTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.BSDSetCreationTimeTests {

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
    func `Sets earlier file creation and newer modification`() throws {

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

        try fileSystem.setTimes(
            forItemAt: path,
            modificationTime: requestedModificationTime,
            creationTime: requestedCreationTime
        )

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
    func `Sets earlier dir creation and newer modification`() throws {

        let path = try workspace.makeDirectory(at: "directory")
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

        try fileSystem.setTimes(
            forItemAt: path,
            modificationTime: requestedModificationTime,
            creationTime: requestedCreationTime
        )

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
    func `No-follow creation set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetTimesBeforeSet = try Support.ItemMetadata.Times.capture(at: target)
        let linkTimesBeforeSet = try Support.ItemMetadata.Times.capture(at: link)
        guard let linkCreationTimeBeforeSet = linkTimesBeforeSet.creation else {
            try Test.cancel("Creation time is unavailable on this platform")
        }
        let requestedCreationTime = shiftedTime(
            from: linkCreationTimeBeforeSet,
            by: -7_200
        )
        let requestedModificationTime = shiftedTime(
            from: linkCreationTimeBeforeSet,
            by: -3_600
        )

        try fileSystem.setTimes(
            forItemAt: link,
            modificationTime: requestedModificationTime,
            creationTime: requestedCreationTime,
            followSymlink: false
        )

        let linkTimesAfterSet = try Support.ItemMetadata.Times.capture(at: link)
        let targetTimesAfterSet = try Support.ItemMetadata.Times.capture(at: target)
        expectCreationTime(
            linkTimesAfterSet.creation,
            equals: .init(fileTimeSpec: requestedCreationTime)
        )
        expectModificationTime(
            linkTimesAfterSet.modification,
            equals: .init(fileTimeSpec: requestedModificationTime)
        )
        #expect(targetTimesAfterSet == targetTimesBeforeSet)

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

        try fileSystem.setTimes(
            forItemAt: path,
            modificationTime: requestedModificationTime
        )

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

        try fileSystem.setTimes(
            forItemAt: path,
            creationTime: requestedCreationTime
        )

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        expectCreationTime(timesAfterSet.creation, equals: creationTimeBeforeSet)
        expectModificationTime(
            timesAfterSet.modification,
            equals: .init(fileTimeSpec: requestedCreationTime)
        )

    }

}

#endif
