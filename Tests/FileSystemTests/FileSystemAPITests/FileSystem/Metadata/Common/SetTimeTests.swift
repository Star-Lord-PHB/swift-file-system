import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Set times")
    struct SetTimeTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.SetTimeTests {

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
    func `Sets file access and modification times`() throws {

        let path = try workspace.makeFile(at: "file")

        try fileSystem.setTimes(
            forItemAt: path,
            accessTime: sampleAccessTime,
            modificationTime: sampleModificationTime
        )

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
    func `Sets dir access and modification times`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        try fileSystem.setTimes(
            forItemAt: path,
            accessTime: sampleAccessTime,
            modificationTime: sampleModificationTime
        )

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

        try fileSystem.setTimes(forItemAt: path, modificationTime: sampleModificationTime)

        let timesAfterModificationSet = try Support.ItemMetadata.Times.capture(at: path)
        expectAccessTime(timesAfterModificationSet.access, equals: timesBeforeSet.access)
        expectModificationTime(
            timesAfterModificationSet.modification,
            equals: .init(fileTimeSpec: sampleModificationTime)
        )

        try fileSystem.setTimes(forItemAt: path, accessTime: sampleAccessTime)

        let timesAfterAccessSet = try Support.ItemMetadata.Times.capture(at: path)
        expectAccessTime(
            timesAfterAccessSet.access,
            equals: .init(fileTimeSpec: sampleAccessTime)
        )
        expectModificationTime(timesAfterAccessSet.modification, equals: timesAfterModificationSet.modification)

    }


    @Test
    func `All nil times leave metadata unchanged`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)

        try fileSystem.setTimes(forItemAt: path)

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        #expect(timesAfterSet == timesBeforeSet)

    }


    @Test
    func `Default set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        try fileSystem.setTimes(
            forItemAt: link,
            accessTime: sampleAccessTime,
            modificationTime: sampleModificationTime
        )

        let targetTimesAfterSet = try Support.ItemMetadata.Times.capture(at: target)
        expectAccessTime(
            targetTimesAfterSet.access,
            equals: .init(fileTimeSpec: sampleAccessTime)
        )
        expectModificationTime(
            targetTimesAfterSet.modification,
            equals: .init(fileTimeSpec: sampleModificationTime)
        )

    }


    @Test
    func `No-follow set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetTimesBeforeSet = try Support.ItemMetadata.Times.capture(at: target)

        try fileSystem.setTimes(
            forItemAt: link,
            accessTime: sampleAccessTime,
            modificationTime: sampleModificationTime,
            followSymlink: false
        )

        let linkTimesAfterSet = try Support.ItemMetadata.Times.capture(at: link)
        let targetTimesAfterSet = try Support.ItemMetadata.Times.capture(at: target)
        expectAccessTime(
            linkTimesAfterSet.access,
            equals: .init(fileTimeSpec: sampleAccessTime)
        )
        expectModificationTime(
            linkTimesAfterSet.modification,
            equals: .init(fileTimeSpec: sampleModificationTime)
        )
        #expect(targetTimesAfterSet == targetTimesBeforeSet)

    }


    @Test
    func `No-follow set handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        try fileSystem.setTimes(
            forItemAt: link,
            accessTime: sampleAccessTime,
            modificationTime: sampleModificationTime,
            followSymlink: false
        )

        let linkTimesAfterSet = try Support.ItemMetadata.Times.capture(at: link)
        expectAccessTime(
            linkTimesAfterSet.access,
            equals: .init(fileTimeSpec: sampleAccessTime)
        )
        expectModificationTime(
            linkTimesAfterSet.modification,
            equals: .init(fileTimeSpec: sampleModificationTime)
        )

    }


    @Test
    func `Default set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setTimes(forItemAt: link, modificationTime: sampleModificationTime)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Setting times for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setTimes(
                forItemAt: path,
                modificationTime: sampleModificationTime
            )
        }

        #expect(error?.kind == .notFound)

    }

}
