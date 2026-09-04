#if canImport(Glibc) || canImport(Musl)

import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("Linux inode flags")
    struct LinuxInodeFlagTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileHandleAPITests.MetadataTests.LinuxInodeFlagTests {

    @Test
    func `inodeFlags matches ioctl`() async throws {

        let path = try workspace.makeFile(at: "file")
        var preparedFlags = try Support.captureNativeInodeFlags(at: path)
        preparedFlags.insert(.noDump)
        try Support.setNativeInodeFlags(preparedFlags, at: path)
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        let flags = try await handle.inodeFlags()

        #expect(try flags == Support.captureNativeInodeFlags(at: path))
        #expect(flags.contains(.noDump))

        try await handle.close()

    }


    @Test
    func `setInodeFlags forwards flags`() async throws {

        let path = try workspace.makeFile(at: "file")
        var requestedFlags = try Support.captureNativeInodeFlags(at: path)
        requestedFlags.insert(.noDump)
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        try await handle.setInodeFlags(requestedFlags)

        try await handle.close()

        #expect(try Support.captureNativeInodeFlags(at: path) == requestedFlags)

    }


    @Test
    func `Pre-cancelled inodeFlags reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.inodeFlags()
        }

    }


    @Test
    func `Pre-cancelled setInodeFlags reports cancellation`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        await Support.expectPreCancelled {
            try await handle.setInodeFlags([])
        }

    }

}

#endif
