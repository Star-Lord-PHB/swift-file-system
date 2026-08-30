import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests {

    @Suite("Metadata forwarding")
    struct MetadataForwardingTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let fileSystem = FileSystem()
        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.MetadataForwardingTests {

    @Test
    func `info forwards the follow-symlinks option`() async throws {

        let missingTarget = workspace.path("missing-target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: missingTarget)

        let linkInfo = try await asyncFileSystem.info(ofItemAt: link, followSymlinks: false)

        let expectedInfo = try fileSystem.info(ofItemAt: link, followSymlinks: false)
        #expect(linkInfo == expectedInfo)

    }


    @Test
    func `info passes through the missing-item error`() async throws {

        let path = workspace.path("missing")

        let error = await #expect(throws: PlatformError.self) {
            try await asyncFileSystem.info(ofItemAt: path)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `setTimes forwards distinct access and modification times`() async throws {

        let path = try workspace.makeFile(at: "file")
        let accessTime = FileTimeSpec(seconds: 1_706_745_678, nanoseconds: 123_456_700)
        let modificationTime = FileTimeSpec(seconds: 1_696_543_210, nanoseconds: 234_567_800)

        try await asyncFileSystem.setTimes(
            forItemAt: path,
            accessTime: accessTime,
            modificationTime: modificationTime
        )

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        Support.expectTimestampEquals(
            timesAfterSet.access,
            .init(fileTimeSpec: accessTime),
            comment: "Access time"
        )
        Support.expectTimestampEquals(
            timesAfterSet.modification,
            .init(fileTimeSpec: modificationTime),
            comment: "Modification time"
        )

    }


    @Test
    func `setAttributes forwards attributes`() async throws {

        let path = try workspace.makeFile(at: "file")
        #if canImport(WinSDK)
        var requestedAttributes = try Support.ItemMetadata.captureAttributes(at: path).values
        requestedAttributes.insert(.windows.isHidden)
        let expectedAttribute = PlatformFileAttributes.windows.isHidden
        #elseif canImport(Glibc) || canImport(Musl)
        let requestedAttributes = [.linux.noDump] as PlatformFileAttributes
        let expectedAttribute = PlatformFileAttributes.linux.noDump
        #else
        let requestedAttributes = [.bsd.noDump] as PlatformFileAttributes
        let expectedAttribute = PlatformFileAttributes.bsd.noDump
        #endif

        try await asyncFileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        #expect(
            try Support.ItemMetadata.captureAttributes(at: path).values
                .contains(expectedAttribute)
        )

    }


    @Test
    func `canAccess forwards a non-default access mode`() async throws {

        let path = try workspace.makeFile(at: "file")

        #expect(try await asyncFileSystem.canAccess(itemAt: path, for: [.read]))

    }


    @Test
    func `getOwner matches the synchronous result`() async throws {

        let path = try workspace.makeFile(at: "file")

        let ownership = try await asyncFileSystem.getOwner(forItemAt: path)

        let expectedOwnership = try fileSystem.getOwner(forItemAt: path)
        #expect(ownership.owner == expectedOwnership.owner)
        #expect(ownership.group == expectedOwnership.group)

    }

}
