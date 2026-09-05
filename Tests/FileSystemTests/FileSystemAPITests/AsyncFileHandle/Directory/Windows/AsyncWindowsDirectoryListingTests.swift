#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.DirectoryTests {

    @Suite("Windows listing")
    struct WindowsListingTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileHandleAPITests.DirectoryTests.WindowsListingTests {

    private func denyListing(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let entries = [
            WindowsExplicitAccess(
                permission: .listDirectory,
                accessMode: .denyAccess,
                trustee: .everyone
            ),
            WindowsExplicitAccess(permission: .genericAll, trustee: .everyone)
        ]
        try Support.setProtectedNativeWindowsDacl(
            WindowsRawAcl(entries: .init(entries)),
            at: path,
            followSymlink: true,
            sourceLocation: sourceLocation
        )
    }


    private func restoreFullAccess(at path: FilePath) {
        let entries = [
            WindowsExplicitAccess(permission: .genericAll, trustee: .everyone)
        ]
        try? Support.setProtectedNativeWindowsDacl(
            WindowsRawAcl(entries: .init(entries)),
            at: path,
            followSymlink: true
        )
    }


    /// Cancels the test when the current token can still list the directory despite the deny ACE
    /// (for example a token with enabled backup privileges).
    private func requireListingDenied(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var findData = WIN32_FIND_DATAW()
        let handle = path.appending("*").withPlatformString { pattern in
            FindFirstFileW(pattern, &findData)
        }
        if let handle, handle != INVALID_HANDLE_VALUE {
            FindClose(handle)
            try Test.cancel(
                "The current token is not subject to the installed deny ACE",
                sourceLocation: sourceLocation
            )
        }
    }

}



// NOTE: A directory list-denied after open is the one deterministic way to make the synchronous
// iterator fail on its first `next()` (the listing resolves the origin path again), which is
// what pins the async error path: the failure surfaces once and the iterator then ends.
extension AsyncFileHandleAPITests.DirectoryTests.WindowsListingTests {

    @Test
    func `Listing a directory list-denied after open fails once and ends`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        try denyListing(at: path)
        defer { restoreFullAccess(at: path) }
        try requireListingDenied(at: path)

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
