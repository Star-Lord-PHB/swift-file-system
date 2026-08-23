#if canImport(WinSDK)

import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Windows creation time")
    struct WindowsCreationTimeCopyTests {

        typealias Support = FileSystemAPITests.Support
        typealias Times = FileSystemTestSupport.ItemMetadata.Times

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.WindowsCreationTimeCopyTests {

    @Test
    func `Overwrite merge raises an older destination creation time`() throws {

        // NOTE: Mirror of the Darwin/BSD birth-time semantics pinned in Metadata/BSD:
        // Windows writes the creation time directly with no lower-only restriction, so
        // even a destination directory older than the source gets the exact value.
        let dst = try workspace.makeDirectory(at: "dst")
        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file")
            ]
        )
        let srcTimes = try Times.capture(at: src)
        let srcCreation = try #require(srcTimes.creation)
        let dstCreationBefore = try #require(try Times.capture(at: dst).creation)
        try #require(dstCreationBefore < srcCreation)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        let dstAfter = try Times.capture(at: dst)
        #expect(dstAfter.creation == srcCreation)
        #expect(dstAfter.modification == srcTimes.modification)

    }

}

#endif
