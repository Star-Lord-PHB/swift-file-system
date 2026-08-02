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


    @Test
    func `Ownership query matches Win32`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)

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
        let handle = try ReadWriteFileHandle(forFileAt: path)

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
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setOwner(owner: nil, group: replacementGroup)

        try handle.close()

        let ownershipAfterSet = try captureOwnership(at: path)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == replacementGroup)

    }


    @Test
    func `Nil owner and group leave ownership unchanged`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try captureOwnership(at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setOwner(owner: nil, group: nil)

        try handle.close()

        let ownershipAfterSet = try captureOwnership(at: path)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == ownershipBeforeSet.group)

    }

}

#endif
