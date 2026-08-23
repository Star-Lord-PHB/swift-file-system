#if canImport(Darwin) || os(FreeBSD)

import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("BSD creation time")
    struct CreationTimeCopyTests {

        typealias Support = FileSystemAPITests.Support
        typealias Times = FileSystemTestSupport.ItemMetadata.Times

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// The copy writes the creation time by setting a modification time earlier than the
// destination's current birth time, which the platform answers by lowering the birth
// time — the write only works downwards. These tests pin both directions; the policy
// consequence (`overwrittenExistingDirPolicy` excluding the creation time for merged
// directories) lives in the Directory suite.
extension FileSystemAPITests.CopyTests.CreationTimeCopyTests {

    /// Ages the item's birth time to one day before its current value and captures the
    /// resulting times.
    private func ageCreationTimeAndCapture(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Times {
        let creation = try #require(
            try Times.capture(at: path, sourceLocation: sourceLocation).creation,
            sourceLocation: sourceLocation
        )
        try Support.ageCreationTime(
            at: path,
            to: creation.adding(seconds: -86_400),
            sourceLocation: sourceLocation
        )
        return try Times.capture(at: path, sourceLocation: sourceLocation)
    }


    @Test
    func `Lowers a new destination file's creation time to the source's`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let srcTimes = try ageCreationTimeAndCapture(at: src)
        let dst = workspace.path("dst.txt")

        try fileSystem.copyItem(at: src, to: dst)

        // The destination is created at copy time, so its birth time starts later than
        // the source's and the downwards write always reaches the exact value.
        let dstTimes = try Times.capture(at: dst)
        #expect(dstTimes.creation == srcTimes.creation)
        #expect(dstTimes.modification == srcTimes.modification)

    }


    @Test
    func `Lowers a new destination directory's creation time to the source's`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "contents")
            ]
        )
        let srcTimes = try ageCreationTimeAndCapture(at: src)
        let dst = workspace.path("dst")

        try fileSystem.copyItem(at: src, to: dst)

        let dstTimes = try Times.capture(at: dst)
        #expect(dstTimes.creation == srcTimes.creation)
        #expect(dstTimes.modification == srcTimes.modification)

    }


    @Test
    func `Overwrite merge cannot raise an older destination creation time`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file")
            ]
        )
        let dst = try workspace.makeDirectory(at: "dst")
        let srcTimes = try Times.capture(at: src)
        let srcCreation = try #require(srcTimes.creation)
        let dstTimes = try ageCreationTimeAndCapture(at: dst)
        let dstCreationBefore = try #require(dstTimes.creation)
        try #require(dstCreationBefore < srcCreation)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        // The merged directory keeps its own older birth time; the other times are
        // still committed from the source.
        let dstAfter = try Times.capture(at: dst)
        #expect(dstAfter.creation == dstCreationBefore)
        #expect(dstAfter.modification == srcTimes.modification)
        try Support.expectItemExistNoFollow(at: dst.appending("file.txt"))

    }

}

#endif
