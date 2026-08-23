#if !canImport(WinSDK)

import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("POSIX ownership")
    struct POSIXOwnershipTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.POSIXOwnershipTests {

    private func captureOwnership(
        at path: FilePath
    ) throws -> Support.ItemMetadata.Security.Ownership {
        try Support.ItemMetadata.captureSecurity(at: path).ownership
    }


    @Test
    func `Ownership query matches stat`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let actual = try handle.owner()
        let expected = try captureOwnership(at: path)

        #expect(actual.owner == expected.owner)
        #expect(actual.group == expected.group)

        try handle.close()

    }

}



extension FileHandleAPITests.MetadataTests.POSIXOwnershipTests {

    // NOTE: Successful owner changes are not tested because they require privileges and
    // a suitable alternate user identity that an ordinary test process cannot rely on.

    @Test
    func `Setting group preserves owner`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try captureOwnership(at: path)
        guard
            let replacementGroup = try Support.replacementGroup(
                excluding: ownershipBeforeSet.group.rawId
            )
        else {
            try Test.cancel("No alternate group is available to the current process")
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
