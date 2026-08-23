import Testing
import Foundation
import SwiftFileSystem



extension UnsafeSystemHandleAPITests {

    /// `UnsafeSystemHandle.openDir(at:)`: routing across the target-kind matrix and the raw
    /// behavior of a directory handle. The path- and handle-based directory enumerators built on
    /// top of it are covered by the DirectorySequence and FileHandle Directory suites.
    @Suite("Directory")
    struct DirectoryTests {

        typealias Support = UnsafeSystemHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension UnsafeSystemHandleAPITests.DirectoryTests {

    @Test
    func `openDir opens a directory`() throws {

        let path = try workspace.makeDirectory(at: "dir")

        let handle = try UnsafeSystemHandle.openDir(at: path)

        #expect(try handle.type() == .directory)

        try handle.close()

    }


    @Test
    func `openDir on a missing path reports notFound`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.openDir(at: path)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `openDir follows a symlink to a directory`() throws {

        let target = try workspace.makeDirectory(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let handle = try UnsafeSystemHandle.openDir(at: link)

        #expect(try handle.type() == .directory)

        try handle.close()

    }


    #if canImport(WinSDK)

    // NOTE: The POSIX side rejects a regular file at open. On Windows,
    // FILE_FLAG_BACKUP_SEMANTICS only permits opening directories in addition to files without
    // restricting the object type; rejecting regular files is added validation of the high-level
    // DirectoryHandle, not raw openDir behavior.
    @Test
    func `openDir opens a regular file`() throws {

        let path = try workspace.makeFile(at: "file")

        let handle = try UnsafeSystemHandle.openDir(at: path)

        #expect(try handle.type() == .regular)

        try handle.close()

    }

    #else

    // NOTE: The Windows side opens a regular file successfully; see the note there.
    @Test
    func `openDir on a regular file reports notADirectory`() throws {

        let path = try workspace.makeFile(at: "file")

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.openDir(at: path)
        }

        #expect(error?.kind == .notADirectory)
        #expect(error?.systemCode == .notADirectory)

    }

    #endif


    @Test
    func `Read on a directory handle is rejected`() throws {

        let path = try workspace.makeDirectory(at: "dir")

        let handle = try UnsafeSystemHandle.openDir(at: path)

        let error = #expect(throws: LowLevelError.self) {
            var buffer = Data(count: 10)
            _ = try handle.read(into: buffer.mutableBytes)
        }

        #if canImport(WinSDK)
        #expect(error?.systemCode == .invalidFunction)
        #else
        #expect(error?.systemCode == .isADirectory)
        #endif

        try handle.close()

    }

}
