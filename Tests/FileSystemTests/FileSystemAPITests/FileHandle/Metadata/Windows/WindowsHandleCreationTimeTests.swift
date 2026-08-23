#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Windows creation time")
    struct WindowsCreationTimeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.WindowsCreationTimeTests {

    @Test
    func `Sets file creation time`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)
        let creationTimeBeforeSet = try #require(timesBeforeSet.creation)
        let requestedCreationTime = creationTimeBeforeSet
            .adding(seconds: -7_200)
            .fileTimeSpec
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileTimes(creation: requestedCreationTime)

        try handle.close()

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        Support.expectTimestampEquals(
            timesAfterSet.creation,
            .init(fileTimeSpec: requestedCreationTime),
            comment: "Creation time"
        )
        Support.expectTimestampEquals(
            timesAfterSet.modification,
            timesBeforeSet.modification,
            comment: "Modification time"
        )

    }

}

#endif
