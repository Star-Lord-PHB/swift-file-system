#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.DirectoryTests {

    @Suite("POSIX listing")
    struct POSIXListingTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileHandleAPITests.DirectoryTests.POSIXListingTests {

    private func setPermissions(_ permissions: Int, at path: FilePath) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: path.string
        )
    }


    /// Restores permissions that would otherwise keep the workspace from being cleaned up.
    private func restoreDefaultDirectoryPermissions(at path: FilePath) {
        try? setPermissions(0o755, at: path)
    }

}



// NOTE: A directory made unreadable after open is the one deterministic way to make the
// synchronous iterator fail on its first `next()` (its reopen is denied), which is what pins the
// async error path: the failure surfaces once and the iterator then ends.
extension AsyncFileHandleAPITests.DirectoryTests.POSIXListingTests {

    @Test
    func `Listing a directory made unreadable after open fails once and ends`() async throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        try setPermissions(0o000, at: path)
        defer { restoreDefaultDirectoryPermissions(at: path) }

        let error = await #expect(throws: PlatformError.self) {
            _ = try await handle.entries()
        }
        #expect(error?.kind == .permissionDenied)

        let sequence = handle.entrySequence()
        var iterator = sequence.makeAsyncIterator()
        var firstError: PlatformError?
        do throws(PlatformError) {
            _ = try await iterator.next()
        } catch {
            firstError = error
        }
        #expect(firstError?.kind == .permissionDenied)
        #expect(try await iterator.next() == nil)
        #expect(iterator.ended == true)

    }

}

#endif
