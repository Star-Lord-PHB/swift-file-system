import SystemPackage
import Testing
import SwiftFileSystem



extension ResourceLifetimeTests {

    @Suite("Queries")
    struct QueryLeakTests {

        typealias Support = ResourceLifetimeTests.Support

        typealias LeakChecker = ResourceLifetimeTests.LeakChecker

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension ResourceLifetimeTests.QueryLeakTests {

    @Test
    func `info does not leak resources`() throws {

        let path = try workspace.makeFile(at: "file.txt", contents: "contents")
        let directory = try workspace.makeDirectory(at: "directory")
        let link = try workspace.makeSymlink(at: "link", pointingTo: "file.txt")

        try LeakChecker.expectNoLeak {
            _ = try fileSystem.info(ofItemAt: path)
            _ = try fileSystem.info(ofItemAt: directory)
            _ = try fileSystem.info(ofItemAt: link)
            _ = try fileSystem.info(ofItemAt: link, followSymlinks: false)
        }

    }


    @Test
    func `info on a missing item does not leak resources`() throws {

        let missing = workspace.path("missing")

        try LeakChecker.expectNoLeak {
            #expect(throws: PlatformError.self) {
                try fileSystem.info(ofItemAt: missing)
            }
        }

    }


    @Test
    func `itemExists does not leak resources`() throws {

        let path = try workspace.makeFile(at: "file.txt", contents: "contents")
        let missing = workspace.path("missing")

        try LeakChecker.expectNoLeak {
            #expect(fileSystem.itemExists(at: path))
            #expect(!fileSystem.itemExists(at: missing))
        }

    }


    @Test
    func `canAccess does not leak resources`() throws {

        let path = try workspace.makeFile(at: "file.txt", contents: "contents")

        try LeakChecker.expectNoLeak {
            let canAccess = try fileSystem.canAccess(itemAt: path, for: [.read, .write])
            #expect(canAccess)
        }

    }


    @Test
    func `destinationOfSymLink does not leak resources`() throws {

        let path = try workspace.makeFile(at: "file.txt", contents: "contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: "file.txt")

        try LeakChecker.expectNoLeak {
            _ = try fileSystem.destinationOfSymLink(at: link)
            #expect(throws: PlatformError.self) {
                try fileSystem.destinationOfSymLink(at: path, recursive: false)
            }
        }

    }


    @Test
    func `setTimes does not leak resources`() throws {

        let path = try workspace.makeFile(at: "file.txt", contents: "contents")

        try LeakChecker.expectNoLeak {
            try fileSystem.setTimes(
                forItemAt: path,
                accessTime: .init(seconds: 1_706_745_678, nanoseconds: 123_456_700),
                modificationTime: .init(seconds: 1_696_543_210, nanoseconds: 234_567_800)
            )
        }

    }

}
