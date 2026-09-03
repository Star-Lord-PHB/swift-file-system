import Testing
import SwiftFileSystem
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests {

    /// Pre-cancelled contract of every throwing method: the standard cancellation error and
    /// no side effect. Most tests target missing paths on purpose — had the body run, the
    /// surfaced error would be `.notFound` instead of `.cancelled`, so the kind assertion
    /// doubles as a body-never-ran proof. Platform-specific shells are covered in their
    /// platform suites.
    @Suite("Cancellation")
    struct CancellationTests {

        typealias Support = AsyncFileSystemAPITests.Support

        let asyncFileSystem = AsyncFileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileSystemAPITests.CancellationTests {

    @Test
    func `Pre-cancelled itemExists still answers`() async throws {

        let path = try workspace.makeFile(at: "file")
        let asyncFileSystem = self.asyncFileSystem

        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return await asyncFileSystem.itemExists(at: path)
        }
        task.cancel()

        #expect(await task.value)

    }


    @Test
    func `Pre-cancelled createFile reports cancellation before creating`() async throws {

        let path = workspace.path("file")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.createFile(at: path)
        }

        try Support.expectItemNotExistNoFollow(at: path)

    }


    @Test
    func `Pre-cancelled createDirectory reports cancellation before creating`() async throws {

        let path = workspace.path("directory")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.createDirectory(at: path)
        }

        try Support.expectItemNotExistNoFollow(at: path)

    }


    @Test
    func `Pre-cancelled moveItem reports cancellation before moving`() async throws {

        let source = try workspace.makeFile(at: "source", contents: "source contents")
        let destination = workspace.path("destination")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.moveItem(at: source, to: destination)
        }

        try Support.expectItemExistNoFollow(at: source)
        try Support.expectItemNotExistNoFollow(at: destination)

    }


    @Test
    func `Pre-cancelled contentsOfDirectory reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.contentsOfDirectory(at: path)
        }

    }


    @Test
    func `Pre-cancelled createSymLink reports cancellation before creating`() async throws {

        let link = workspace.path("link")
        let target = workspace.path("target")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.createSymLink(at: link, pointingTo: target)
        }

        try Support.expectItemNotExistNoFollow(at: link)

    }


    @Test
    func `Pre-cancelled createHardLink reports cancellation before creating`() async throws {

        let link = workspace.path("link")
        let existing = try workspace.makeFile(at: "existing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.createHardLink(at: link, for: existing)
        }

        try Support.expectItemNotExistNoFollow(at: link)

    }


    @Test
    func `Pre-cancelled destinationOfSymLink reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.destinationOfSymLink(at: path)
        }

    }


    @Test
    func `Pre-cancelled info reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.info(ofItemAt: path)
        }

    }


    @Test
    func `Pre-cancelled setTimes reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.setTimes(forItemAt: path)
        }

    }


    @Test
    func `Pre-cancelled setAttributes reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.setAttributes(forItemAt: path, attributes: [])
        }

    }


    @Test
    func `Pre-cancelled canAccess reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.canAccess(itemAt: path)
        }

    }


    @Test
    func `Pre-cancelled getOwner reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.getOwner(forItemAt: path)
        }

    }


    @Test
    func `Pre-cancelled setOwner reports cancellation`() async throws {

        let path = workspace.path("missing")
        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.setOwner(forItemAt: path, owner: nil, group: nil)
        }

    }


    @Test
    func `Pre-cancelled working-dir query reports cancellation`() async throws {

        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.currentWorkingDirectoryPath()
        }

    }


    @Test
    func `Pre-cancelled executable-path query reports cancellation`() async throws {

        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.executablePath()
        }

    }


    @Test
    func `Pre-cancelled home-dir query reports cancellation`() async throws {

        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.homeDirectoryPath()
        }

    }


    @Test
    func `Pre-cancelled temp-dir query reports cancellation`() async throws {

        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.tempDirectoryPath()
        }

    }


    @Test
    func `Pre-cancelled cache-dir query reports cancellation`() async throws {

        let asyncFileSystem = self.asyncFileSystem

        await Support.expectPreCancelled {
            try await asyncFileSystem.cacheDirectoryPath()
        }

    }

}
