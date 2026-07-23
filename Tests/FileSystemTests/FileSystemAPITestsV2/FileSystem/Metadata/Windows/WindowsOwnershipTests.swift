#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Windows ownership")
    struct WindowsOwnershipTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.WindowsOwnershipTests {

    @Test
    func `File ownership query matches Win32`() throws {

        let path = try workspace.makeFile(at: "file")

        let actual = try fileSystem.getOwner(forItemAt: path)
        let expected = try Support.captureWindowsOwnership(at: path, followSymlink: true)

        #expect(actual.owner.rawId == expected.owner)
        #expect(actual.group.rawId == expected.group)

    }


    @Test
    func `Dir ownership query matches Win32`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let actual = try fileSystem.getOwner(forItemAt: path)
        let expected = try Support.captureWindowsOwnership(at: path, followSymlink: true)

        #expect(actual.owner.rawId == expected.owner)
        #expect(actual.group.rawId == expected.group)

    }


    @Test
    func `Ownership query follows symlinks by default`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let actual = try fileSystem.getOwner(forItemAt: link)
        let expected = try Support.captureWindowsOwnership(at: link, followSymlink: true)

        #expect(actual.owner.rawId == expected.owner)
        #expect(actual.group.rawId == expected.group)

    }


    @Test
    func `No-follow ownership query returns symlink ownership`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let actual = try fileSystem.getOwner(
            forItemAt: link,
            followSymlink: false
        )
        let expected = try Support.captureWindowsOwnership(at: link, followSymlink: false)

        #expect(actual.owner.rawId == expected.owner)
        #expect(actual.group.rawId == expected.group)

    }


    @Test
    func `No-follow ownership query handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let actual = try fileSystem.getOwner(
            forItemAt: link,
            followSymlink: false
        )
        let expected = try Support.captureWindowsOwnership(at: link, followSymlink: false)

        #expect(actual.owner.rawId == expected.owner)
        #expect(actual.group.rawId == expected.group)

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



extension FileSystemAPITests.MetadataTests.WindowsOwnershipTests {

    // NOTE: A meaningful owner change requires a different SID that the current
    // token may assign as an owner. The current user is preferred; an owner-capable
    // group is used only when the current user already owns the item.

    @Test
    func `Setting owner preserves group`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try Support.captureWindowsOwnership(at: path, followSymlink: true)
        guard 
            let replacementOwner = try Support.replacementOwner(excluding: ownershipBeforeSet.owner)
        else {
            try Test.cancel("The current token has no alternate assignable owner")
        }

        try fileSystem.setOwner(
            forItemAt: path,
            owner: replacementOwner,
            group: nil
        )

        let ownershipAfterSet = try Support.captureWindowsOwnership(at: path, followSymlink: true)
        #expect(ownershipAfterSet.owner == replacementOwner.rawId)
        #expect(ownershipAfterSet.group == ownershipBeforeSet.group)

    }


    @Test
    func `Setting group preserves owner`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try Support.captureWindowsOwnership(at: path, followSymlink: true)
        guard 
            let replacementGroup = try Support.replacementGroup(excluding: ownershipBeforeSet.group) 
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }

        try fileSystem.setOwner(
            forItemAt: path,
            owner: nil,
            group: replacementGroup
        )

        let ownershipAfterSet = try Support.captureWindowsOwnership(at: path, followSymlink: true)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == replacementGroup.rawId)

    }


    @Test
    func `Setting dir group preserves owner`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let ownershipBeforeSet = try Support.captureWindowsOwnership(at: path, followSymlink: true)
        guard 
            let replacementGroup = try Support.replacementGroup(excluding: ownershipBeforeSet.group) 
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }

        try fileSystem.setOwner(
            forItemAt: path,
            owner: nil,
            group: replacementGroup
        )

        let ownershipAfterSet = try Support.captureWindowsOwnership(at: path, followSymlink: true)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == replacementGroup.rawId)

    }


    @Test
    func `Nil owner and group leave ownership unchanged`() throws {

        let path = try workspace.makeFile(at: "file")
        let ownershipBeforeSet = try Support.captureWindowsOwnership(at: path, followSymlink: true)

        try fileSystem.setOwner(forItemAt: path, owner: nil, group: nil)

        let ownershipAfterSet = try Support.captureWindowsOwnership(at: path, followSymlink: true)
        #expect(ownershipAfterSet.owner == ownershipBeforeSet.owner)
        #expect(ownershipAfterSet.group == ownershipBeforeSet.group)

    }


    @Test
    func `Default ownership set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetOwnershipBeforeSet = try Support.captureWindowsOwnership(
            at: target,
            followSymlink: true
        )
        let linkOwnershipBeforeSet = try Support.captureWindowsOwnership(
            at: link,
            followSymlink: false
        )
        guard 
            let replacementGroup = try Support.replacementGroup(excluding: targetOwnershipBeforeSet.group) 
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }

        try fileSystem.setOwner(
            forItemAt: link,
            owner: nil,
            group: replacementGroup
        )

        let targetOwnershipAfterSet = try Support.captureWindowsOwnership(at: target, followSymlink: true)
        let linkOwnershipAfterSet = try Support.captureWindowsOwnership(at: link, followSymlink: false)
        #expect(targetOwnershipAfterSet.owner == targetOwnershipBeforeSet.owner)
        #expect(targetOwnershipAfterSet.group == replacementGroup.rawId)
        #expect(linkOwnershipAfterSet.owner == linkOwnershipBeforeSet.owner)
        #expect(linkOwnershipAfterSet.group == linkOwnershipBeforeSet.group)

    }


    @Test
    func `No-follow ownership set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetOwnershipBeforeSet = try Support.captureWindowsOwnership(
            at: target,
            followSymlink: true
        )
        let linkOwnershipBeforeSet = try Support.captureWindowsOwnership(
            at: link,
            followSymlink: false
        )
        guard 
            let replacementGroup = try Support.replacementGroup(excluding: linkOwnershipBeforeSet.group) 
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }

        try fileSystem.setOwner(
            forItemAt: link,
            owner: nil,
            group: replacementGroup,
            followSymlink: false
        )

        let targetOwnershipAfterSet = try Support.captureWindowsOwnership(at: target, followSymlink: true)
        let linkOwnershipAfterSet = try Support.captureWindowsOwnership(at: link, followSymlink: false)
        #expect(targetOwnershipAfterSet.owner == targetOwnershipBeforeSet.owner)
        #expect(targetOwnershipAfterSet.group == targetOwnershipBeforeSet.group)
        #expect(linkOwnershipAfterSet.owner == linkOwnershipBeforeSet.owner)
        #expect(linkOwnershipAfterSet.group == replacementGroup.rawId)

    }


    @Test
    func `No-follow ownership set handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkOwnershipBeforeSet = try Support.captureWindowsOwnership(
            at: link,
            followSymlink: false
        )
        guard 
            let replacementGroup = try Support.replacementGroup(excluding: linkOwnershipBeforeSet.group)
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }

        try fileSystem.setOwner(
            forItemAt: link,
            owner: nil,
            group: replacementGroup,
            followSymlink: false
        )

        let linkOwnershipAfterSet = try Support.captureWindowsOwnership(
            at: link,
            followSymlink: false
        )
        #expect(linkOwnershipAfterSet.owner == linkOwnershipBeforeSet.owner)
        #expect(linkOwnershipAfterSet.group == replacementGroup.rawId)

    }


    @Test
    func `Default ownership set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkOwnershipBeforeSet = try Support.captureWindowsOwnership(
            at: link,
            followSymlink: false
        )
        let currentUser = try Support.currentUserIdentity()

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setOwner(
                forItemAt: link,
                owner: currentUser,
                group: nil
            )
        }

        let linkOwnershipAfterSet = try Support.captureWindowsOwnership(
            at: link,
            followSymlink: false
        )
        #expect(error?.kind == .notFound)
        #expect(linkOwnershipAfterSet.owner == linkOwnershipBeforeSet.owner)
        #expect(linkOwnershipAfterSet.group == linkOwnershipBeforeSet.group)

    }


    @Test
    func `Setting ownership for missing item fails`() throws {

        let path = workspace.path("missing")
        let currentUser = try Support.currentUserIdentity()

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setOwner(
                forItemAt: path,
                owner: currentUser,
                group: nil
            )
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
