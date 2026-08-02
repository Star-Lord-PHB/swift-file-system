#if !canImport(WinSDK)

import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("POSIX non-writable handle setters")
    struct POSIXNonWritableHandleSetterTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.POSIXNonWritableHandleSetterTests {

    // NOTE: POSIX metadata syscalls operate on the file, not the descriptor's access
    // mode, so metadata setters succeed even through read-only and directory handles.
    // Windows requires write-metadata access rights at open, so the same calls are
    // denied there; see the Windows non-writable handle setter suite for the diverging assertions.

    private var sampleAccessTime: FileTimeSpec {
        .init(seconds: 1_706_745_678, nanoseconds: 123_456_700)
    }


    private var sampleModificationTime: FileTimeSpec {
        .init(seconds: 1_696_543_210, nanoseconds: 234_567_800)
    }


    private func expectSampleTimes(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let timesAfterSet = try Support.ItemMetadata.Times.capture(
            at: path,
            sourceLocation: sourceLocation
        )
        Support.expectTimestampEquals(
            timesAfterSet.access,
            .init(fileTimeSpec: sampleAccessTime),
            comment: "Access time",
            sourceLocation: sourceLocation
        )
        Support.expectTimestampEquals(
            timesAfterSet.modification,
            .init(fileTimeSpec: sampleModificationTime),
            comment: "Modification time",
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `Read-only handle sets file times`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadFileHandle(forFileAt: path)

        try handle.setFileTimes(
            access: sampleAccessTime,
            modification: sampleModificationTime
        )

        try handle.close()

        try expectSampleTimes(at: path)

    }


    @Test
    func `Read-only handle sets permissions`() throws {

        let requestedPermissions = FilePermissions(rawValue: 0o640)
        let path = try workspace.makeFile(at: "file")
        let handle = try ReadFileHandle(forFileAt: path)

        try handle.setPosixPermissions(requestedPermissions)

        try handle.close()

        #expect(
            try Support.ItemMetadata.captureSecurity(at: path).permissions
                == requestedPermissions
        )

    }


    @Test
    func `Directory handle sets file times`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let handle = try DirectoryHandle(forDirAt: path)

        try handle.setFileTimes(
            access: sampleAccessTime,
            modification: sampleModificationTime
        )

        try handle.close()

        try expectSampleTimes(at: path)

    }

}

#endif
