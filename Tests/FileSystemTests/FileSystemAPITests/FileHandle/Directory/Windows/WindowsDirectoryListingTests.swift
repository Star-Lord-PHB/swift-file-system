#if canImport(WinSDK)

import Foundation
import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests.DirectoryTests {

    @Suite("Windows listing")
    struct WindowsListingTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.DirectoryTests.WindowsListingTests {

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



extension FileHandleAPITests.DirectoryTests.WindowsListingTests {

    @Test
    func `List-denied directory open fails`() throws {

        let path = try workspace.makeDirectory(at: "locked")
        try denyListing(at: path)
        defer { restoreFullAccess(at: path) }
        try requireListingDenied(at: path)

        let error = #expect(throws: PlatformError.self) {
            _ = try DirectoryHandle(forDirAt: path)
        }

        #expect(error?.kind == .permissionDenied)

    }


    @Test
    func `Listing a directory list-denied after open fails once and ends`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try DirectoryHandle(forDirAt: path)
        try denyListing(at: path)
        defer { restoreFullAccess(at: path) }
        try requireListingDenied(at: path)

        // The listing goes through FindFirstFile on the origin path, so a deny ACE installed after
        // open is observed even though the handle itself stays valid.
        let error = #expect(throws: PlatformError.self) {
            _ = try handle.entries()
        }
        #expect(error?.kind == .permissionDenied)

        let sequence = handle.entrySequence()
        var iterator = sequence.makeIterator()
        let first = iterator.next()
        let firstError = #expect(throws: PlatformError.self) {
            try first?.get()
        }
        #expect(firstError?.kind == .permissionDenied)
        #expect(iterator.next() == nil)
        #expect(iterator.ended == true)

    }


    @Test
    func `Listing after directory rename reports not-found`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents")
            ]
        )
        let movedPath = workspace.path("moved")
        let handle = try DirectoryHandle(forDirAt: path)

        try FileManager.default.moveItem(atPath: path.string, toPath: movedPath.string)

        // NOTE: Windows lists through FindFirstFile on the origin path rather than through the handle,
        // so a rename after open makes the listing fail. POSIX keeps listing the renamed directory
        // through the descriptor (see the POSIX listing suite).
        try #require(!FileManager.default.fileExists(atPath: path.string))
        let error = #expect(throws: PlatformError.self) {
            _ = try handle.entries()
        }
        #expect(error?.kind == .notFound)

        try handle.close()

    }

}

#endif
