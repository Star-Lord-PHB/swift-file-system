import Foundation
import SystemPackage
import Testing
import SwiftFileSystem
import SwiftFileSystemFoundationCompat



extension FileInfoAPITests {

    @Suite("Query")
    struct QueryTests {

        typealias Support = FileInfoAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileInfoAPITests.QueryTests {

    private var timeToleranceNanoseconds: Int {
        #if canImport(WinSDK)
            100_000
        #else
            1_000
        #endif
    }


    private var accessTimeToleranceNanoseconds: Int {
        #if canImport(WinSDK)
            1_000_000_000
        #else
            timeToleranceNanoseconds
        #endif
    }


    private func expectFileTimeEquals(
        _ actual: FileTimes,
        _ expected: Support.ItemMetadata.Times,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        Support.expectDateEquals(
            actual.lastAccess.date,
            expected.access,
            toleranceNanoseconds: accessTimeToleranceNanoseconds,
            comment: "Access time",
            sourceLocation: sourceLocation
        )
        Support.expectDateEquals(
            actual.lastModification.date,
            expected.modification,
            toleranceNanoseconds: timeToleranceNanoseconds,
            comment: "Modification time",
            sourceLocation: sourceLocation
        )
        Support.expectDateEquals(
            actual.lastChange.date,
            expected.statusChange,
            toleranceNanoseconds: timeToleranceNanoseconds,
            comment: "Status change time",
            sourceLocation: sourceLocation
        )
        Support.expectDateEquals(
            actual.creation?.date,
            expected.creation,
            toleranceNanoseconds: timeToleranceNanoseconds,
            comment: "Creation time",
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `FileInfo queries regular file metadata`() throws {

        let path = try workspace.makeFile(
            at: "file",
            contents: "file contents"
        )

        let info = try FileInfo(fileAt: path)
        let expected = try Support.ItemMetadata.capture(at: path)

        #expect(info.type == .regular)
        #expect(info.size == expected.size)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))
        expectFileTimeEquals(info.times, expected.times)

    }


    @Test
    func `FileInfo queries dir metadata`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let info = try FileInfo(fileAt: path)
        let expected = try Support.ItemMetadata.capture(at: path)

        #expect(info.type == .directory)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))
        expectFileTimeEquals(info.times, expected.times)

    }


    @Test
    func `FileInfo follows symlinks by default`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let info = try FileInfo(fileAt: link)
        let expected = try Support.ItemMetadata.capture(at: link)

        #expect(info.type == .regular)
        #expect(info.size == expected.size)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))
        expectFileTimeEquals(info.times, expected.times)

    }


    @Test
    func `FileInfo can query a symlink itself`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let info = try FileInfo(fileAt: link, followSymLink: false)

        #expect(info.type == .symlink)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `FileInfo no-follow queries a dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let info = try FileInfo(fileAt: link, followSymLink: false)

        #expect(info.type == .symlink)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `FileInfo default query fails for a dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try FileInfo(fileAt: link)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `FileInfo query fails for a missing item`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try FileInfo(fileAt: path)
        }

        #expect(error?.kind == .notFound)

    }
}
