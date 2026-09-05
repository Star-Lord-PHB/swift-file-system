#if canImport(WinSDK)

import Foundation
import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.DirectoryTests {

    /// `ReOpenDir` (CFileSystem): reopening an open directory handle as a new file object, the
    /// Windows counterpart of `openat(fd, ".")` that the handle-based directory listing builds on.
    @Suite("Windows ReOpenDir")
    struct WindowsReOpenDirTests {

        typealias Support = UnsafeSystemHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension UnsafeSystemHandleAPITests.DirectoryTests.WindowsReOpenDirTests {

    @Test
    func `ReOpenDir returns a new handle to the same directory`() throws {

        let path = try workspace.makeDirectory(at: "dir")
        let handle = try UnsafeSystemHandle.openDir(at: path)

        let raw: HANDLE? = ReOpenDir(handle.unsafeRawHandle)
        let reopenedRaw = try #require(raw)
        try #require(reopenedRaw != INVALID_HANDLE_VALUE)
        let reopened = UnsafeSystemHandle(owningRawHandle: reopenedRaw)

        #expect(reopenedRaw != handle.unsafeRawHandle)
        #expect(try reopened.type() == .directory)
        #expect(try reopened.fileInfo().fileIdentifier == handle.fileInfo().fileIdentifier)

        try reopened.close()
        try handle.close()

    }


    @Test
    func `ReOpenDir follows the directory across a rename`() throws {

        let path = try workspace.makeDirectory(at: "dir")
        let movedPath = workspace.path("moved")
        let handle = try UnsafeSystemHandle.openDir(at: path)
        let identifier = try handle.fileInfo().fileIdentifier

        try FileManager.default.moveItem(atPath: path.string, toPath: movedPath.string)
        try #require(!FileManager.default.fileExists(atPath: path.string))

        let raw: HANDLE? = ReOpenDir(handle.unsafeRawHandle)
        let reopenedRaw = try #require(raw)
        try #require(reopenedRaw != INVALID_HANDLE_VALUE)
        let reopened = UnsafeSystemHandle(owningRawHandle: reopenedRaw)

        #expect(try reopened.fileInfo().fileIdentifier == identifier)

        try reopened.close()
        try handle.close()

    }


    @Test
    func `ReOpenDir handle can query directory entries`() throws {

        let path = try workspace.makeFixture(
            at: "dir",
            [
                "file": .file(contents: "contents")
            ]
        )
        let handle = try UnsafeSystemHandle.openDir(at: path)

        let raw: HANDLE? = ReOpenDir(handle.unsafeRawHandle)
        let reopenedRaw = try #require(raw)
        try #require(reopenedRaw != INVALID_HANDLE_VALUE)
        let reopened = UnsafeSystemHandle(owningRawHandle: reopenedRaw)

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
    func `ReOpenDir handle is not inheritable`() throws {

        let path = try workspace.makeDirectory(at: "dir")
        let handle = try UnsafeSystemHandle.openDir(at: path)

        let raw: HANDLE? = ReOpenDir(handle.unsafeRawHandle)
        let reopenedRaw = try #require(raw)
        try #require(reopenedRaw != INVALID_HANDLE_VALUE)
        let reopened = UnsafeSystemHandle(owningRawHandle: reopenedRaw)

        var handleFlags = 0 as DWORD
        try #require(GetHandleInformation(reopened.unsafeRawHandle, &handleFlags))
        #expect((handleFlags & DWORD(HANDLE_FLAG_INHERIT)) == 0)

        try reopened.close()
        try handle.close()

    }


    @Test
    func `ReOpenDir on a file handle reports ERROR_DIRECTORY`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init())

        let raw: HANDLE? = ReOpenDir(handle.unsafeRawHandle)
        let error = GetLastError()

        #expect(raw == INVALID_HANDLE_VALUE)
        #expect(error == DWORD(ERROR_DIRECTORY))

        try handle.close()

    }


    @Test
    func `ReOpenDir on a non-file handle reports ERROR_INVALID_HANDLE`() throws {

        let raw: HANDLE? = ReOpenDir(GetCurrentProcess())
        let error = GetLastError()

        #expect(raw == INVALID_HANDLE_VALUE)
        #expect(error == DWORD(ERROR_INVALID_HANDLE))

    }

}

#endif
