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
// view; each method is executor dispatch of the synchronous extension on `SyncHandleAdapter`, so
// the forwarding and cancellation contracts are proven once here on the read handle, the
// least privileged kind: on Windows every setter reopens for the rights it needs, so this is
// the path with the most machinery behind it. The platform-conditional shells (POSIX
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
    func `info matches path-based FileInfo`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        let actual = try await handle.info()
        let expected = try FileInfo(forItemAt: path)

        #expect(actual == expected)

        try await handle.close()

    }


    @Test
    func `type returns regular`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        #expect(try await handle.type() == .regular)

        try await handle.close()

    }


    @Test
    func `times matches independently captured times`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        let expected = try Support.ItemMetadata.Times.capture(at: path)

        let actual = try await handle.times()

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
    func `setTimes forwards distinct access and modification times`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        try await handle.setTimes(access: sampleAccessTime, modification: sampleModificationTime)

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
    func `attributes matches captured attributes`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        let actual = try await handle.attributes()
        let expected = try Support.ItemMetadata.captureAttributes(at: path).values

        #expect(actual == expected)

        try await handle.close()

    }


    @Test
    func `setAttributes forwards attributes`() async throws {

        let path = try workspace.makeFile(at: "file")
        #if canImport(WinSDK)
        var requestedAttributes = try Support.ItemMetadata.captureAttributes(at: path).values
        requestedAttributes.insert(.windows.isHidden)
        let expectedAttribute = PlatformFileAttributes.windows.isHidden
        #elseif os(Linux) || os(Android)
        let requestedAttributes = [.linux.noDump] as PlatformFileAttributes
        let expectedAttribute = PlatformFileAttributes.linux.noDump
        #else
        let requestedAttributes = [.bsd.noDump] as PlatformFileAttributes
        let expectedAttribute = PlatformFileAttributes.bsd.noDump
        #endif
        try Support.requireAttributeQueryAvailable(for: expectedAttribute, at: path)
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        try await handle.setAttributes(requestedAttributes)

        try await handle.close()

        #expect(
            try Support.ItemMetadata.captureAttributes(at: path).values
                .contains(expectedAttribute)
        )

    }


    @Test
    func `owner matches captured ownership`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

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
    func `Pre-cancelled info reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.info()
        }

    }


    @Test
    func `Pre-cancelled type reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.type()
        }

    }


    @Test
    func `Pre-cancelled times reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.times()
        }

    }


    @Test
    func `Pre-cancelled setTimes reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)
        let accessTime = sampleAccessTime

        await Support.expectPreCancelled {
            try await handle.setTimes(access: accessTime)
        }

    }


    @Test
    func `Pre-cancelled attributes reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.attributes()
        }

    }


    @Test
    func `Pre-cancelled setAttributes reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.setAttributes([])
        }

    }


    @Test
    func `Pre-cancelled owner reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.owner()
        }

    }


    @Test
    func `Pre-cancelled setOwner reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let currentGroup = try Support.ItemMetadata.captureSecurity(at: path).ownership.group
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.setOwner(owner: nil, group: currentGroup)
        }

    }

}
