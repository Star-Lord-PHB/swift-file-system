#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Windows creation-time setting")
    struct WindowsSetCreationTimeTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.WindowsSetCreationTimeTests {

    private var sampleCreationTime: FileTimeSpec {
        .init(seconds: 13_335_033_678, nanoseconds: 123_456_700)
    }


    private var sampleCreationTimestamp: Support.ItemMetadata.Timestamp {
        .init(fileTimeSpec: sampleCreationTime)
    }


    @Test
    func `Sets file creation time`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)

        try fileSystem.setTimes(
            forItemAt: path,
            creationTime: sampleCreationTime
        )

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        #expect(timesAfterSet.creation == sampleCreationTimestamp)
        #expect(timesAfterSet.access == timesBeforeSet.access)
        #expect(timesAfterSet.modification == timesBeforeSet.modification)

    }


    @Test
    func `Sets dir creation time`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)

        try fileSystem.setTimes(
            forItemAt: path,
            creationTime: sampleCreationTime
        )

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        #expect(timesAfterSet.creation == sampleCreationTimestamp)
        #expect(timesAfterSet.access == timesBeforeSet.access)
        #expect(timesAfterSet.modification == timesBeforeSet.modification)

    }


    @Test
    func `Default creation-time set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let linkTimesBeforeSet = try Support.ItemMetadata.Times.capture(at: link)

        try fileSystem.setTimes(
            forItemAt: link,
            creationTime: sampleCreationTime
        )

        let targetTimesAfterSet = try Support.ItemMetadata.Times.capture(at: target)
        let linkTimesAfterSet = try Support.ItemMetadata.Times.capture(at: link)
        #expect(targetTimesAfterSet.creation == sampleCreationTimestamp)
        #expect(linkTimesAfterSet.creation == linkTimesBeforeSet.creation)

    }


    @Test
    func `No-follow creation-time set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetTimesBeforeSet = try Support.ItemMetadata.Times.capture(at: target)

        try fileSystem.setTimes(
            forItemAt: link,
            creationTime: sampleCreationTime,
            followSymlink: false
        )

        let linkTimesAfterSet = try Support.ItemMetadata.Times.capture(at: link)
        let targetTimesAfterSet = try Support.ItemMetadata.Times.capture(at: target)
        #expect(linkTimesAfterSet.creation == sampleCreationTimestamp)
        #expect(targetTimesAfterSet == targetTimesBeforeSet)

    }


    @Test
    func `No-follow creation-time set handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(
            at: "link",
            pointingTo: "missing-target"
        )

        try fileSystem.setTimes(
            forItemAt: link,
            creationTime: sampleCreationTime,
            followSymlink: false
        )

        let linkTimesAfterSet = try Support.ItemMetadata.Times.capture(at: link)
        #expect(linkTimesAfterSet.creation == sampleCreationTimestamp)

    }


    @Test
    func `Default creation-time set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(
            at: "link",
            pointingTo: "missing-target"
        )

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setTimes(
                forItemAt: link,
                creationTime: sampleCreationTime
            )
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Setting creation time for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setTimes(
                forItemAt: path,
                creationTime: sampleCreationTime
            )
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
