#if !canImport(WinSDK)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("POSIX ownership")
    struct POSIXOwnershipTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.POSIXOwnershipTests {

    private func captureOwnership(
        at path: FilePath
    ) throws -> Support.ItemMetadata.Security.Ownership {
        try Support.ItemMetadata.captureSecurity(at: path).ownership
    }


    @Test
    func `File ownership query matches stat`() throws {

        let path = try workspace.makeFile(at: "file")

        let actual = try fileSystem.getOwner(forItemAt: path)
        let expected = try captureOwnership(at: path)

        #expect(actual.owner == expected.owner)
        #expect(actual.group == expected.group)

    }


    @Test
    func `Dir ownership query matches stat`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let actual = try fileSystem.getOwner(forItemAt: path)
        let expected = try captureOwnership(at: path)

        #expect(actual.owner == expected.owner)
        #expect(actual.group == expected.group)

    }


    @Test
    func `Ownership query follows symlinks by default`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let actual = try fileSystem.getOwner(forItemAt: link)
        let expected = try captureOwnership(at: target)

        #expect(actual.owner == expected.owner)
        #expect(actual.group == expected.group)

    }


    @Test
    func `No-follow ownership query returns symlink ownership`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let actual = try fileSystem.getOwner(
            forItemAt: link,
            followSymlink: false
        )
        let expected = try captureOwnership(at: link)

        #expect(actual.owner == expected.owner)
        #expect(actual.group == expected.group)

    }


    @Test
    func `No-follow ownership query handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let actual = try fileSystem.getOwner(
            forItemAt: link,
            followSymlink: false
        )
        let expected = try captureOwnership(at: link)

        #expect(actual.owner == expected.owner)
        #expect(actual.group == expected.group)

    }


    @Test
    func `Default ownership query fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getOwner(forItemAt: link)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Missing ownership query fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getOwner(forItemAt: path)
        }

        #expect(error?.kind == .notFound)

    }

}



extension FileSystemAPITests.MetadataTests.POSIXOwnershipTests {

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

        try fileSystem.setOwner(forItemAt: path, owner: nil, group: replacementGroup)

        let ownershipAfterSet = try captureOwnership(at: path)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == replacementGroup)

    }


    @Test
    func `Default ownership set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetOwnershipBeforeSet = try captureOwnership(at: target)
        let linkOwnershipBeforeSet = try captureOwnership(at: link)
        guard 
            let replacementGroup = try Support.replacementGroup(
                excluding: targetOwnershipBeforeSet.group.rawId
            )
        else {
            try Test.cancel("No alternate group is available to the current process")
        }

        try fileSystem.setOwner(forItemAt: link, owner: nil, group: replacementGroup)

        let targetOwnershipAfterSet = try captureOwnership(at: target)
        let linkOwnershipAfterSet = try captureOwnership(at: link)
        #expect(targetOwnershipAfterSet.owner == targetOwnershipBeforeSet.owner)
        #expect(targetOwnershipAfterSet.group == replacementGroup)
        #expect(linkOwnershipAfterSet.owner == linkOwnershipBeforeSet.owner)
        #expect(linkOwnershipAfterSet.group == linkOwnershipBeforeSet.group)

    }


    @Test
    func `No-follow ownership set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetOwnershipBeforeSet = try captureOwnership(at: target)
        let linkOwnershipBeforeSet = try captureOwnership(at: link)
        guard 
            let replacementGroup = try Support.replacementGroup(
                excluding: linkOwnershipBeforeSet.group.rawId
            )
        else {
            try Test.cancel("No alternate group is available to the current process")
        }

        try fileSystem.setOwner(
            forItemAt: link,
            owner: nil,
            group: replacementGroup,
            followSymlink: false
        )

        let targetOwnershipAfterSet = try captureOwnership(at: target)
        let linkOwnershipAfterSet = try captureOwnership(at: link)
        #expect(targetOwnershipAfterSet.owner == targetOwnershipBeforeSet.owner)
        #expect(targetOwnershipAfterSet.group == targetOwnershipBeforeSet.group)
        #expect(linkOwnershipAfterSet.owner == linkOwnershipBeforeSet.owner)
        #expect(linkOwnershipAfterSet.group == replacementGroup)

    }


    @Test
    func `No-follow ownership set handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkOwnershipBeforeSet = try captureOwnership(at: link)
        guard 
            let replacementGroup = try Support.replacementGroup(
                excluding: linkOwnershipBeforeSet.group.rawId
            )
        else {
            try Test.cancel("No alternate group is available to the current process")
        }

        try fileSystem.setOwner(
            forItemAt: link,
            owner: nil,
            group: replacementGroup,
            followSymlink: false
        )

        let linkOwnershipAfterSet = try captureOwnership(at: link)
        #expect(linkOwnershipAfterSet.owner == linkOwnershipBeforeSet.owner)
        #expect(linkOwnershipAfterSet.group == replacementGroup)

    }


    @Test
    func `Default ownership set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkOwnershipBeforeSet = try captureOwnership(at: link)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setOwner(forItemAt: link, owner: nil, group: linkOwnershipBeforeSet.group)
        }

        let linkOwnershipAfterSet = try captureOwnership(at: link)
        #expect(error?.kind == .notFound)
        #expect(linkOwnershipAfterSet.owner == linkOwnershipBeforeSet.owner)
        #expect(linkOwnershipAfterSet.group == linkOwnershipBeforeSet.group)

    }


    @Test
    func `Nil owner and group leave ownership unchanged`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try captureOwnership(at: path)

        try fileSystem.setOwner(forItemAt: path, owner: nil, group: nil)

        let ownershipAfterSet = try captureOwnership(at: path)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == ownershipBeforeSet.group)

    }


    @Test
    func `Setting ownership for missing item fails`() throws {

        let path = workspace.path("missing")
        let owner = PlatformIdentity(rawId: UInt32(geteuid()), platformKind: .user)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setOwner(forItemAt: path, owner: owner, group: nil)
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
