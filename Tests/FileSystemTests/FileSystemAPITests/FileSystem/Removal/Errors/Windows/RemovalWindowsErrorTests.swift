#if canImport(WinSDK)

import SystemPackage
import Testing
import WinSDK
import SwiftFileSystem



extension FileSystemAPITests.RemovalTests {

    /// Failures only Windows can produce: the READONLY attribute and handles held open without
    /// delete sharing.
    @Suite("Windows errors")
    struct RemovalWindowsErrorTests {

        typealias Support = FileSystemAPITests.Support
        typealias RemovalTests = FileSystemAPITests.RemovalTests

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.RemovalTests.RemovalWindowsErrorTests {

    private func setNativeAttributes(
        _ attributes: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let success = path.withPlatformString { pathPointer in
            SetFileAttributesW(pathPointer, attributes.rawValue)
        }
        try #require(success, sourceLocation: sourceLocation)
    }


    /// READONLY blocks deletion and would break the workspace cleanup; call from a `defer`.
    private func clearNativeAttributes(at path: FilePath) {
        _ = path.withPlatformString { pathPointer in
            SetFileAttributesW(pathPointer, PlatformFileAttributes.windows.isNormal.rawValue)
        }
    }


    /// Opens `path` for reading without FILE_SHARE_DELETE, which makes every open for DELETE
    /// access fail with a sharing violation while reads and listings still work; close the handle
    /// from a `defer`. The handle must hold a data right: one with attribute rights alone takes no
    /// part in sharing checks.
    private func holdOpen(
        _ path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> HANDLE? {
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(GENERIC_READ),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_FLAG_BACKUP_SEMANTICS),
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        return handle
    }


    // `DeleteFileW` rejects a READONLY file with `ERROR_ACCESS_DENIED`, the code it also gives
    // for a directory, so a `RemoveDirectoryW` retry follows; its "not a directory" answer must
    // not replace the original error.
    @Test
    func `READONLY file removal reports the DeleteFileW error`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        try setNativeAttributes(.windows.isReadOnly, at: path)
        defer { clearNativeAttributes(at: path) }
        let snapshot = try Support.ItemSnapshot.capture(at: path)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: path)
        }

        #expect(error?.kind == .permissionDenied)
        #expect(error?.systemCode == .accessDenied)
        #expect(error?.operation == .remove(path))
        try Support.expectItem(at: path, matches: snapshot, using: .unchanged)

    }


    @Test
    func `READONLY file inside a tree is reported and everything else is removed`() throws {

        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a-file": .file(contents: "a"),
                "sub": [
                    "read-only": .file(contents: "read-only contents"),
                    "sibling": .file(contents: "sibling contents"),
                    "nested": [
                        "file": .file(contents: "nested contents")
                    ],
                ],
                "z-dir": [
                    "file": .file(contents: "z contents")
                ],
            ]
        )
        let readOnlyPath = root.appending("sub/read-only")
        try setNativeAttributes(.windows.isReadOnly, at: readOnlyPath)
        defer { clearNativeAttributes(at: readOnlyPath) }
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.kind == .permissionDenied)
        #expect(error?.systemCode == .accessDenied)
        #expect(error?.operation == .remove(readOnlyPath))
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        for removed in ["a-file", "sub/sibling", "sub/nested/file", "sub/nested", "z-dir/file", "z-dir"] as [FilePath] {
            expectation.removeItem(at: removed)
        }
        try expectation.updatePolicies([
            "": RemovalTests.survivingDirectoryPolicy,
            "sub": RemovalTests.survivingDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }


    @Test
    func `File held open without delete sharing is reported and the rest is removed`() throws {

        let root = try workspace.makeFixture(
            at: "directory",
            [
                "a-file": .file(contents: "a"),
                "sub": [
                    "held": .file(contents: "held contents")
                ],
                "z-dir": [
                    "file": .file(contents: "z contents")
                ],
            ]
        )
        let heldPath = root.appending("sub/held")
        let handle = try holdOpen(heldPath)
        defer { CloseHandle(handle) }
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.systemCode == .sharingViolation)
        #expect(error?.operation == .remove(heldPath))
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        for removed in ["a-file", "z-dir/file", "z-dir"] as [FilePath] {
            expectation.removeItem(at: removed)
        }
        try expectation.updatePolicies([
            "": RemovalTests.survivingDirectoryPolicy,
            "sub": RemovalTests.enumeratedDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }


    @Test
    func `Directory held open without delete sharing is reported after its contents are removed`() throws {

        let root = try workspace.makeFixture(
            at: "directory",
            [
                "held": [
                    "file": .file(contents: "held contents"),
                    "sub": [
                        "deep": .file(contents: "deep contents")
                    ],
                ],
                "z-file": .file(contents: "z"),
            ]
        )
        let heldPath = root.appending("held")
        let handle = try holdOpen(heldPath)
        defer { CloseHandle(handle) }
        let rootSnapshot = try Support.TreeSnapshot.capture(at: root)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.removeItem(at: root)
        }

        #expect(error?.systemCode == .sharingViolation)
        #expect(error?.operation == .remove(heldPath))
        var expectation = Support.TreeExpectation(matching: rootSnapshot, using: .unchanged)
        for removed in ["z-file", "held/file", "held/sub/deep", "held/sub"] as [FilePath] {
            expectation.removeItem(at: removed)
        }
        try expectation.updatePolicies([
            "": RemovalTests.survivingDirectoryPolicy,
            "held": RemovalTests.survivingDirectoryPolicy,
        ])
        try Support.expectTree(at: root, matches: expectation)

    }

}

#endif
