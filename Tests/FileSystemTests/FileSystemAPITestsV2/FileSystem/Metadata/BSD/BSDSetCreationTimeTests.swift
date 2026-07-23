#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

import Foundation
import Testing
import SwiftFileSystem
import SwiftFileSystemFoundationCompat



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

    private var timeToleranceNanoseconds: Int {
        1_000
    }


    private func shiftedTime(
        from date: Date,
        by seconds: TimeInterval
    ) -> FileTimeSpec {
        .init(from: date.addingTimeInterval(seconds))
    }


    private func expectCreationTime(
        _ actual: Date?,
        equals expected: Date?,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        Support.expectDateEquals(
            actual,
            expected,
            toleranceNanoseconds: timeToleranceNanoseconds,
            comment: "Creation time",
            sourceLocation: sourceLocation
        )
    }


    private func expectModificationTime(
        _ actual: Date?,
        equals expected: Date?,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        Support.expectDateEquals(
            actual,
            expected,
            toleranceNanoseconds: timeToleranceNanoseconds,
            comment: "Modification time",
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `Sets earlier file creation and newer modification`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(
            at: path,
            followSymlink: true
        )
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

        let timesAfterSet = try Support.ItemMetadata.Times.capture(
            at: path,
            followSymlink: true
        )
        expectCreationTime(timesAfterSet.creation, equals: requestedCreationTime.date)
        expectModificationTime(timesAfterSet.modification, equals: requestedModificationTime.date)

    }


    @Test
    func `Sets earlier dir creation and newer modification`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(
            at: path,
            followSymlink: true
        )
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

        let timesAfterSet = try Support.ItemMetadata.Times.capture(
            at: path,
            followSymlink: true
        )
        expectCreationTime(timesAfterSet.creation, equals: requestedCreationTime.date)
        expectModificationTime(timesAfterSet.modification, equals: requestedModificationTime.date)

    }


    @Test
    func `No-follow creation set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetTimesBeforeSet = try Support.ItemMetadata.Times.capture(
            at: target,
            followSymlink: true
        )
        let linkTimesBeforeSet = try Support.ItemMetadata.Times.capture(
            at: link,
            followSymlink: false
        )
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

        let linkTimesAfterSet = try Support.ItemMetadata.Times.capture(
            at: link,
            followSymlink: false
        )
        let targetTimesAfterSet = try Support.ItemMetadata.Times.capture(
            at: target,
            followSymlink: true
        )
        expectCreationTime(linkTimesAfterSet.creation, equals: requestedCreationTime.date)
        expectModificationTime(linkTimesAfterSet.modification, equals: requestedModificationTime.date)
        #expect(targetTimesAfterSet == targetTimesBeforeSet)

    }


    @Test
    func `Earlier modification also moves creation`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(
            at: path,
            followSymlink: true
        )
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

        let timesAfterSet = try Support.ItemMetadata.Times.capture(
            at: path,
            followSymlink: true
        )
        expectCreationTime(timesAfterSet.creation, equals: requestedModificationTime.date)
        expectModificationTime(timesAfterSet.modification, equals: requestedModificationTime.date)

    }


    @Test
    func `Later creation request preserves creation but updates modification`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(
            at: path,
            followSymlink: true
        )
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

        let timesAfterSet = try Support.ItemMetadata.Times.capture(
            at: path,
            followSymlink: true
        )
        expectCreationTime(timesAfterSet.creation, equals: creationTimeBeforeSet)
        expectModificationTime(timesAfterSet.modification, equals: requestedCreationTime.date)

    }

}

#endif
