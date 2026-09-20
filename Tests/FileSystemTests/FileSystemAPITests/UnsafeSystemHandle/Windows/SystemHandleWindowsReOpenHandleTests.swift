#if canImport(WinSDK)

import Foundation
import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.WindowsTests {

    /// `ReOpenHandle` (CFileSystem) behind `reOpen(withAccess:openOptions:)` and `reOpenForDir()`:
    /// reopening an open file or directory handle as a new file object with exactly the requested
    /// access rights. Directories reopen the way `openat(fd, ".")` does on POSIX, which the
    /// handle-based directory listing builds on; files reopen for the metadata setters that need
    /// rights the original open did not request.
    @Suite("ReOpenHandle")
    struct ReOpenHandleTests {

        typealias Support = UnsafeSystemHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension UnsafeSystemHandleAPITests.WindowsTests.ReOpenHandleTests {

    private var sampleModificationTime: FileTimeSpec {
        .init(seconds: 1_696_543_210, nanoseconds: 234_567_800)
    }


    // Installs a protected DACL granting `permission` to everyone. The rights are chosen per test;
    // `.delete` is always included so the workspace can remove the item afterwards.
    private func installProtectedDacl(
        granting permission: WindowsAccessMask,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try Support.setProtectedNativeWindowsDacl(
            WindowsRawAcl(entries: [
                WindowsExplicitAccess(
                    permission: permission.union(.delete),
                    inheritance: .noInheritance,
                    trustee: .everyone
                )
            ]),
            at: path,
            followSymlink: false,
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `Directory reopen returns a new handle to the same directory`() throws {

        let path = try workspace.makeDirectory(at: "dir")
        let handle = try UnsafeSystemHandle.openDir(at: path)
        let sourceRawHandle = handle.unsafeRawHandle

        let reopened = try handle.reOpenForDir()
        let reopenedRawHandle = reopened.unsafeRawHandle

        #expect(reopenedRawHandle != sourceRawHandle)
        #expect(try reopened.type() == .directory)
        #expect(try reopened.fileInfo().fileIdentifier == handle.fileInfo().fileIdentifier)

        try reopened.close()
        try handle.close()

    }


    @Test
    func `Directory reopen follows the directory across a rename`() throws {

        let path = try workspace.makeDirectory(at: "dir")
        let movedPath = workspace.path("moved")
        let handle = try UnsafeSystemHandle.openDir(at: path)
        let identifier = try handle.fileInfo().fileIdentifier

        try FileManager.default.moveItem(atPath: path.string, toPath: movedPath.string)
        try #require(!FileManager.default.fileExists(atPath: path.string))

        let reopened = try handle.reOpenForDir()

        #expect(try reopened.fileInfo().fileIdentifier == identifier)

        try reopened.close()
        try handle.close()

    }


    @Test
    func `Reopened directory handle can query directory entries`() throws {

        let path = try workspace.makeFixture(
            at: "dir",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try UnsafeSystemHandle.openDir(at: path)

        let reopened = try handle.reOpenForDir()

        let bufferSize = 65536
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 8)
        defer { buffer.deallocate() }
        let queried = GetFileInformationByHandleEx(
            reopened.unsafeRawHandle,
            FileIdExtdDirectoryRestartInfo,
            buffer,
            DWORD(bufferSize)
        )
        let error = GetLastError()
        #expect(queried, "GetFileInformationByHandleEx failed with Win32 error \(error)")

        try reopened.close()
        try handle.close()

    }


    @Test
    func `Reopened handle is not inheritable`() throws {

        let path = try workspace.makeDirectory(at: "dir")
        let handle = try UnsafeSystemHandle.openDir(at: path)

        let reopened = try handle.reOpenForDir()

        var handleFlags = 0 as DWORD
        try #require(GetHandleInformation(reopened.unsafeRawHandle, &handleFlags))
        #expect((handleFlags & DWORD(HANDLE_FLAG_INHERIT)) == 0)

        try reopened.close()
        try handle.close()

    }


    // The reopened handle carries its own rights: a read-only source cannot set times, the handle
    // reopened for attribute writes can, and both name the same file.
    @Test
    func `File reopen lends the requested rights on the same file`() throws {

        let path = try workspace.makeFile(at: "file")
        let source = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly))
        let modificationTime = sampleModificationTime

        let sourceError = #expect(throws: LowLevelError.self) {
            try source.setFileTimes(modification: modificationTime)
        }
        #expect(sourceError?.kind == .permissionDenied)

        let reopened = try source.reOpen(withAccess: [.readAttributes, .writeAttributes])

        try reopened.setFileTimes(modification: modificationTime)

        #expect(try reopened.fileInfo().fileIdentifier == source.fileInfo().fileIdentifier)
        Support.expectTimestampEquals(
            try Support.ItemMetadata.Times.capture(at: path).modification,
            .init(fileTimeSpec: modificationTime),
            comment: "Modification time"
        )

        try reopened.close()
        try source.close()

    }


    // Unlike `CreateFileW`, the reopen requests nothing behind the caller's back: on a DACL without
    // SYNCHRONIZE the exact mask opens while the same mask plus SYNCHRONIZE is denied. The whole
    // per-call reopen design rests on this.
    @Test
    func `Reopen requests nothing beyond the given mask`() throws {

        let path = try workspace.makeFile(at: "file")
        let source = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly))
        try installProtectedDacl(granting: [.readControl, .writeDAC], at: path)

        let exact = try source.reOpen(withAccess: [.readControl])
        try exact.close()

        let error = #expect(throws: LowLevelError.self) {
            _ = try source.reOpen(withAccess: [.readControl, .synchronize])
        }
        #expect(error?.kind == .permissionDenied)

        try source.close()

    }


    // Rights are checked against the DACL current at reopen time, not the one the source handle
    // was opened under; the source handle itself keeps the rights it was granted.
    @Test
    func `Reopen runs a fresh access check against the current DACL`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let source = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly))
        try installProtectedDacl(granting: [.readControl, .synchronize], at: path)

        let error = #expect(throws: LowLevelError.self) {
            _ = try source.reOpen(withAccess: [.writeAttributes])
        }
        #expect(error?.kind == .permissionDenied)
        #expect(try source.fileInfo().size == 8)

        try source.close()

    }


    @Test
    func `Directory option on a file handle reports not a directory`() throws {

        let path = try workspace.makeFile(at: "file")
        let source = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly))

        let error = #expect(throws: LowLevelError.self) {
            _ = try source.reOpen(withAccess: [.readAttributes], openOptions: ULONG(FILE_DIRECTORY_FILE))
        }
        #expect(error?.systemCode == .invalidDirectoryName)
        #expect(error?.kind == .notADirectory)

        try source.close()

    }


    @Test
    func `Reopen of a non-file handle reports an invalid handle`() throws {

        let raw: HANDLE? = ReOpenHandle(GetCurrentProcess(), DWORD(FILE_READ_ATTRIBUTES), 0)
        let error = GetLastError()

        #expect(raw == INVALID_HANDLE_VALUE)
        #expect(error == DWORD(ERROR_INVALID_HANDLE))

    }

}

#endif
