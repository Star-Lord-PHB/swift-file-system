#if canImport(Glibc) || canImport(Musl)

import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests {

    @Suite("Linux inode flag forwarding")
    struct LinuxInodeFlagForwardingTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.LinuxInodeFlagForwardingTests {

    @Test
    func `getInodeFlags matches ioctl`() async throws {

        let path = try workspace.makeFile(at: "file")
        var preparedFlags = try Support.captureNativeInodeFlags(at: path)
        preparedFlags.insert(.noDump)
        try Support.setNativeInodeFlags(preparedFlags, at: path)

        let flags = try await asyncFileSystem.getInodeFlags(forItemAt: path)

        #expect(try flags == Support.captureNativeInodeFlags(at: path))
        #expect(flags.contains(.noDump))

    }


    @Test
    func `setInodeFlags forwards flags`() async throws {

        let path = try workspace.makeFile(at: "file")
        var requestedFlags = try Support.captureNativeInodeFlags(at: path)
        requestedFlags.insert(.noDump)

        try await asyncFileSystem.setInodeFlags(forItemAt: path, flags: requestedFlags)

        #expect(try Support.captureNativeInodeFlags(at: path) == requestedFlags)

    }


    @Test
    func `Pre-cancelled getInodeFlags reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await AsyncFileSystemAPITests.expectPreCancelled {
            try await asyncFileSystem.getInodeFlags(forItemAt: path)
        }

    }


    @Test
    func `Pre-cancelled setInodeFlags reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await AsyncFileSystemAPITests.expectPreCancelled {
            try await asyncFileSystem.setInodeFlags(forItemAt: path, flags: [])
        }

    }

}

#endif
