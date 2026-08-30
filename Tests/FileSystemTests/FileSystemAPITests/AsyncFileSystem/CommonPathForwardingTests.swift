import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests {

    /// The synchronous results are already verified against Foundation by the
    /// `FileSystem/CommonPaths` group, so plain equality with them is the whole contract.
    @Suite("Common path forwarding")
    struct CommonPathForwardingTests {

        let fileSystem = FileSystem()
        let asyncFileSystem = AsyncFileSystem()

    }

}



extension AsyncFileSystemAPITests.CommonPathForwardingTests {

    @Test
    func `Current working dir matches the synchronous result`() async throws {

        let path = try await asyncFileSystem.currentWorkingDirectoryPath()

        #expect(try path == fileSystem.currentWorkingDirectoryPath())

    }


    @Test
    func `Executable path matches the synchronous result`() async throws {

        let path = try await asyncFileSystem.executablePath()

        #expect(try path == fileSystem.executablePath())

    }


    @Test
    func `Home dir matches the synchronous result`() async throws {

        let path = try await asyncFileSystem.homeDirectoryPath()

        #expect(try path == fileSystem.homeDirectoryPath())

    }


    @Test
    func `Temp dir matches the synchronous result`() async throws {

        let path = try await asyncFileSystem.tempDirectoryPath()

        #expect(try path == fileSystem.tempDirectoryPath())

    }


    @Test
    func `Cache dir matches the synchronous result`() async throws {

        let path = try await asyncFileSystem.cacheDirectoryPath()

        #expect(try path == fileSystem.cacheDirectoryPath())

    }

}
