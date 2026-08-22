import SystemPackage
import Testing
import SwiftFileSystem



extension ResourceLifetimeTests {

    /// Open paths that acquire a native handle and then reject the item must close that
    /// handle before throwing. The caller never sees a handle, so only process-wide counting
    /// can observe these paths (on Windows the no-follow truncate rejection and the
    /// `DirectoryHandle` type check both happen after a successful native open).
    @Suite("Open rejection")
    struct HandleOpenLeakTests {

        typealias Support = ResourceLifetimeTests.Support

        typealias LeakChecker = ResourceLifetimeTests.LeakChecker

        let workspace: Support.Workspace
        let filePath: FilePath
        let link: FilePath


        init() throws {
            workspace = try Support.Workspace()
            let root = try workspace.makeFixture(
                at: "area",
                [
                    "target.txt": .file(contents: "contents"),
                    "link": .symlink(target: "target.txt"),
                ]
            )
            filePath = root.appending("target.txt")
            link = root.appending("link")
        }

    }

}



extension ResourceLifetimeTests.HandleOpenLeakTests {

    @Test
    func `WriteFileHandle rejecting a no-follow truncate symlink does not leak resources`() throws {

        try LeakChecker.expectNoLeak {
            #expect(throws: PlatformError.self) {
                _ = try WriteFileHandle(
                    forFileAt: link,
                    options: .editFile(createIfMissing: false, truncate: true, noFollow: true)
                )
            }
        }

    }


    @Test
    func `ReadWriteFileHandle rejecting a no-follow truncate symlink does not leak resources`() throws {

        try LeakChecker.expectNoLeak {
            #expect(throws: PlatformError.self) {
                _ = try ReadWriteFileHandle(
                    forFileAt: link,
                    options: .editFile(createIfMissing: false, truncate: true, noFollow: true)
                )
            }
        }

    }


    @Test
    func `AppendHandle rejecting a no-follow truncate symlink does not leak resources`() throws {

        try LeakChecker.expectNoLeak {
            #expect(throws: PlatformError.self) {
                _ = try AppendHandle(
                    forFileAt: link,
                    options: .editFile(createIfMissing: false, truncate: true, noFollow: true)
                )
            }
        }

    }


    @Test
    func `DirectoryHandle rejecting a regular file does not leak resources`() throws {

        try LeakChecker.expectNoLeak {
            #expect(throws: PlatformError.self) {
                _ = try DirectoryHandle(forDirAt: filePath)
            }
        }

    }

}
