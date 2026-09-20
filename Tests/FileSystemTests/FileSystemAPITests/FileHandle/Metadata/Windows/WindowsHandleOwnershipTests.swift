#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Windows ownership")
    struct WindowsOwnershipTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.WindowsOwnershipTests {

    private func captureOwnership(
        at path: FilePath
    ) throws -> Support.ItemMetadata.Security.Ownership {
        try Support.ItemMetadata.captureSecurity(at: path).ownership
    }


    // Installs a protected DACL granting everyone read, write and execute but not WRITE_OWNER;
    // `.delete` is included so the workspace can remove the file afterwards.
    private func installProtectedDaclWithoutWriteOwner(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try Support.setProtectedNativeWindowsDacl(
            WindowsRawAcl(entries: [
                WindowsExplicitAccess(
                    permission: .init(rawValue: FILE_GENERIC_READ | FILE_GENERIC_WRITE | FILE_GENERIC_EXECUTE)
                        .union(.delete),
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
    func `Ownership query matches Win32`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadFileHandle(forFileAt: path)

        let actual = try handle.owner()
        let expected = try captureOwnership(at: path)

        #expect(actual.owner == expected.owner)
        #expect(actual.group == expected.group)

        try handle.close()

    }

}



extension FileHandleAPITests.MetadataTests.WindowsOwnershipTests {

    // NOTE: A meaningful owner change requires a different SID that the current
    // token may assign as an owner. The current user is preferred; an owner-capable
    // group is used only when the current user already owns the item.

    @Test
    func `Setting owner preserves group`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try captureOwnership(at: path)
        guard
            let replacementOwner = try Support.replacementOwner(
                excluding: ownershipBeforeSet.owner.rawId
            )
        else {
            try Test.cancel("The current token has no alternate assignable owner")
        }
        let handle = try ReadFileHandle(forFileAt: path)

        try handle.setOwner(owner: replacementOwner, group: nil)

        try handle.close()

        let ownershipAfterSet = try captureOwnership(at: path)
        #expect(ownershipAfterSet.owner == replacementOwner)
        #expect(ownershipAfterSet.group == ownershipBeforeSet.group)

    }


    @Test
    func `Setting group preserves owner`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try captureOwnership(at: path)
        guard
            let replacementGroup = try Support.replacementGroup(
                excluding: ownershipBeforeSet.group.rawId
            )
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }
        let handle = try ReadFileHandle(forFileAt: path)

        try handle.setOwner(owner: nil, group: replacementGroup)

        try handle.close()

        let ownershipAfterSet = try captureOwnership(at: path)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == replacementGroup)

    }


    // WRITE_OWNER is never implicit, so a DACL without it denies the reopen behind the setter
    // even for the owner.
    @Test
    func `Group set is denied when the DACL lacks write-owner`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try captureOwnership(at: path)
        guard
            let replacementGroup = try Support.replacementGroup(
                excluding: ownershipBeforeSet.group.rawId
            )
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }
        let handle = try ReadFileHandle(forFileAt: path)
        try installProtectedDaclWithoutWriteOwner(at: path)

        let error = #expect(throws: PlatformError.self) {
            try handle.setOwner(owner: nil, group: replacementGroup)
        }

        #expect(error?.kind == .permissionDenied)
        #expect(try captureOwnership(at: path).group == ownershipBeforeSet.group)

        try handle.close()

    }


    @Test
    func `Nil owner and group leave ownership unchanged`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try captureOwnership(at: path)
        let handle = try ReadFileHandle(forFileAt: path)

        try handle.setOwner(owner: nil, group: nil)

        try handle.close()

        let ownershipAfterSet = try captureOwnership(at: path)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == ownershipBeforeSet.group)

    }

}

#endif
