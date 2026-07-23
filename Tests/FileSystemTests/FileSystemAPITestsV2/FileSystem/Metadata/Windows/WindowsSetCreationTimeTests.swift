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


    private var sampleCreationTimeTicks: Int64 {
        Int64(sampleCreationTime.seconds) * 10_000_000
            + Int64(sampleCreationTime.nanoseconds / 100)
    }


    @Test
    func `Sets file creation time`() throws {

        let path = try workspace.makeFile(at: "file")
        let infoBeforeSet = try Support.captureWindowsBasicInfo(
            at: path,
            followSymlink: true
        )

        try fileSystem.setTimes(
            forItemAt: path,
            creationTime: sampleCreationTime
        )

        let infoAfterSet = try Support.captureWindowsBasicInfo(
            at: path,
            followSymlink: true
        )
        #expect(infoAfterSet.creationTime == sampleCreationTimeTicks)
        #expect(infoAfterSet.accessTime == infoBeforeSet.accessTime)
        #expect(infoAfterSet.modificationTime == infoBeforeSet.modificationTime)

    }


    @Test
    func `Sets dir creation time`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let infoBeforeSet = try Support.captureWindowsBasicInfo(
            at: path,
            followSymlink: true
        )

        try fileSystem.setTimes(
            forItemAt: path,
            creationTime: sampleCreationTime
        )

        let infoAfterSet = try Support.captureWindowsBasicInfo(
            at: path,
            followSymlink: true
        )
        #expect(infoAfterSet.creationTime == sampleCreationTimeTicks)
        #expect(infoAfterSet.accessTime == infoBeforeSet.accessTime)
        #expect(infoAfterSet.modificationTime == infoBeforeSet.modificationTime)

    }


    @Test
    func `Default creation-time set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let linkInfoBeforeSet = try Support.captureWindowsBasicInfo(
            at: link,
            followSymlink: false
        )

        try fileSystem.setTimes(
            forItemAt: link,
            creationTime: sampleCreationTime
        )

        let targetInfoAfterSet = try Support.captureWindowsBasicInfo(
            at: target,
            followSymlink: true
        )
        let linkInfoAfterSet = try Support.captureWindowsBasicInfo(
            at: link,
            followSymlink: false
        )
        #expect(targetInfoAfterSet.creationTime == sampleCreationTimeTicks)
        #expect(linkInfoAfterSet.creationTime == linkInfoBeforeSet.creationTime)

    }


    @Test
    func `No-follow creation-time set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetInfoBeforeSet = try Support.captureWindowsBasicInfo(
            at: target,
            followSymlink: true
        )

        try fileSystem.setTimes(
            forItemAt: link,
            creationTime: sampleCreationTime,
            followSymlink: false
        )

        let linkInfoAfterSet = try Support.captureWindowsBasicInfo(
            at: link,
            followSymlink: false
        )
        let targetInfoAfterSet = try Support.captureWindowsBasicInfo(
            at: target,
            followSymlink: true
        )
        #expect(linkInfoAfterSet.creationTime == sampleCreationTimeTicks)
        #expect(targetInfoAfterSet == targetInfoBeforeSet)

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

        let linkInfoAfterSet = try Support.captureWindowsBasicInfo(
            at: link,
            followSymlink: false
        )
        #expect(linkInfoAfterSet.creationTime == sampleCreationTimeTicks)

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
