#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Windows non-writable handle setters")
    struct WindowsNonWritableHandleSetterTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.WindowsNonWritableHandleSetterTests {

    // NOTE: Read-only and directory handles open without FILE_WRITE_ATTRIBUTES,
    // WRITE_DAC and WRITE_OWNER, so metadata setters are denied on Windows. The same
    // calls succeed on POSIX because its metadata syscalls ignore the descriptor's
    // access mode; see the POSIX non-writable handle setter suite for the diverging assertions.

    private var sampleModificationTime: FileTimeSpec {
        .init(seconds: 1_696_543_210, nanoseconds: 234_567_800)
    }


    @Test
    func `Read-only handle time set is denied`() throws {

        let path = try workspace.makeFile(at: "file")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)
        let handle = try ReadFileHandle(forFileAt: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.setFileTimes(modification: sampleModificationTime)
        }

        try handle.close()

        #expect(error?.kind == .permissionDenied)
        Support.expectTimestampEquals(
            try Support.ItemMetadata.Times.capture(at: path).modification,
            timesBeforeSet.modification,
            comment: "Modification time"
        )

    }


    @Test
    func `Read-only handle attribute set is denied`() throws {

        let path = try workspace.makeFile(at: "file")
        let attributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        let requestedAttributes = attributesBeforeSet
            .subtracting(.windows.isNormal)
            .union([.windows.isHidden])
        let handle = try ReadFileHandle(forFileAt: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.setFileAttributes(requestedAttributes)
        }

        try handle.close()

        #expect(error?.kind == .permissionDenied)
        #expect(try Support.ItemMetadata.captureAttributes(at: path).values == attributesBeforeSet)

    }


    @Test
    func `Read-only handle DACL set is denied`() throws {

        let path = try workspace.makeFile(at: "file")
        let securityBeforeSet = try Support.ItemMetadata.captureSecurity(at: path)
        let replacementDacl = WindowsRawAcl(
            entries: [
                WindowsExplicitAccess(
                    permission: .init(rawValue: FILE_GENERIC_READ),
                    inheritance: .noInheritance,
                    trustee: .everyone
                )
            ]
        )
        let handle = try ReadFileHandle(forFileAt: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.setSecurityInfo(dacl: .replace(replacementDacl))
        }

        try handle.close()

        #expect(error?.kind == .permissionDenied)
        Support.expectWindowsSecurity(
            try Support.ItemMetadata.captureSecurity(at: path),
            matches: securityBeforeSet
        )

    }


    @Test
    func `Read-only handle group set is denied`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try Support.ItemMetadata.captureSecurity(at: path).ownership
        guard
            let replacementGroup = try Support.replacementGroup(
                excluding: ownershipBeforeSet.group.rawId
            )
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }
        let handle = try ReadFileHandle(forFileAt: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.setOwner(owner: nil, group: replacementGroup)
        }

        try handle.close()

        #expect(error?.kind == .permissionDenied)
        let ownershipAfterSet = try Support.ItemMetadata.captureSecurity(at: path).ownership
        #expect(ownershipAfterSet.group == ownershipBeforeSet.group)

    }


    @Test
    func `Directory handle time set is denied`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let timesBeforeSet = try Support.ItemMetadata.Times.capture(at: path)
        let handle = try DirectoryHandle(forDirAt: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.setFileTimes(modification: sampleModificationTime)
        }

        try handle.close()

        #expect(error?.kind == .permissionDenied)
        Support.expectTimestampEquals(
            try Support.ItemMetadata.Times.capture(at: path).modification,
            timesBeforeSet.modification,
            comment: "Modification time"
        )

    }

}

#endif
