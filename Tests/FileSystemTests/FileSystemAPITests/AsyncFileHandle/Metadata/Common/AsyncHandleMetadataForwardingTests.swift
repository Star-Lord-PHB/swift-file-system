import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("Forwarding")
    struct ForwardingTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The metadata family is one protocol extension shared by every async handle kind and
// view; each method is executor dispatch of the synchronous extension on `SyncHandleView`, so
// the forwarding and cancellation contracts are proven once here on the read-write handle,
// whose open rights let every method succeed. The platform-conditional shells (POSIX
// permissions, Linux inode flags, Windows security) live in their own suites, and the
// per-kind plumbing is covered by the all-handle-types suite. `SwiftFileSystem` is imported
// for the path-based `FileInfo` oracle only.
extension AsyncFileHandleAPITests.MetadataTests.ForwardingTests {

    private var sampleAccessTime: FileTimeSpec {
        .init(seconds: 1_706_745_678, nanoseconds: 123_456_700)
    }


    private var sampleModificationTime: FileTimeSpec {
        .init(seconds: 1_696_543_210, nanoseconds: 234_567_800)
    }


    @Test
    func `fileInfo matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        let actual = try await handle.fileInfo()
        let expected = try FileInfo(fileAt: path)

        #expect(actual == expected)

        try await handle.close()

    }


    @Test
    func `type returns regular`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        #expect(try await handle.type() == .regular)

        try await handle.close()

    }


    @Test
    func `fileTimes matches independently captured times`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        let expected = try Support.ItemMetadata.Times.capture(at: path)

        let actual = try await handle.fileTimes()

        Support.expectTimestampEquals(
            .init(fileTimeSpec: actual.lastAccess),
            expected.access,
            comment: "Access time"
        )
        Support.expectTimestampEquals(
            .init(fileTimeSpec: actual.lastModification),
            expected.modification,
            comment: "Modification time"
        )
        Support.expectTimestampEquals(
            .init(fileTimeSpec: actual.lastChange),
            expected.statusChange,
            comment: "Status-change time"
        )
        Support.expectTimestampEquals(
            actual.creation.map { .init(fileTimeSpec: $0) },
            expected.creation,
            comment: "Creation time"
        )

        try await handle.close()

    }


    @Test
    func `setFileTimes forwards distinct access and modification times`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        try await handle.setFileTimes(access: sampleAccessTime, modification: sampleModificationTime)

        try await handle.close()

        let timesAfterSet = try Support.ItemMetadata.Times.capture(at: path)
        Support.expectTimestampEquals(
            timesAfterSet.access,
            .init(fileTimeSpec: sampleAccessTime),
            comment: "Access time"
        )
        Support.expectTimestampEquals(
            timesAfterSet.modification,
            .init(fileTimeSpec: sampleModificationTime),
            comment: "Modification time"
        )

    }


    @Test
    func `fileAttributes matches captured attributes`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        let actual = try await handle.fileAttributes()
        let expected = try Support.ItemMetadata.captureAttributes(at: path).values

        #expect(actual == expected)

        try await handle.close()

    }


    @Test
    func `setFileAttributes forwards attributes`() async throws {

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
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        try await handle.setFileAttributes(requestedAttributes)

        try await handle.close()

        #expect(
            try Support.ItemMetadata.captureAttributes(at: path).values
                .contains(expectedAttribute)
        )

    }


    @Test
    func `owner matches captured ownership`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        let actual = try await handle.owner()
        let expected = try Support.ItemMetadata.captureSecurity(at: path).ownership

        #expect(actual.owner == expected.owner)
        #expect(actual.group == expected.group)

        try await handle.close()

    }

}



// Pre-cancelled contract of every cross-platform metadata shell. The handle is open, so a
// body that ran would succeed; the `.cancelled` kind is the body-never-ran proof.
extension AsyncFileHandleAPITests.MetadataTests.ForwardingTests {

    @Test
    func `Pre-cancelled fileInfo reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.fileInfo()
        }

    }


    @Test
    func `Pre-cancelled type reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.type()
        }

    }


    @Test
    func `Pre-cancelled fileTimes reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.fileTimes()
        }

    }


    @Test
    func `Pre-cancelled setFileTimes reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)
        let accessTime = sampleAccessTime

        await Support.expectPreCancelled {
            try await handle.setFileTimes(access: accessTime)
        }

    }


    @Test
    func `Pre-cancelled fileAttributes reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.fileAttributes()
        }

    }


    @Test
    func `Pre-cancelled setFileAttributes reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.setFileAttributes([])
        }

    }


    @Test
    func `Pre-cancelled owner reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.owner()
        }

    }


    @Test
    func `Pre-cancelled setOwner reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let currentGroup = try Support.ItemMetadata.captureSecurity(at: path).ownership.group
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.setOwner(owner: nil, group: currentGroup)
        }

    }

}
