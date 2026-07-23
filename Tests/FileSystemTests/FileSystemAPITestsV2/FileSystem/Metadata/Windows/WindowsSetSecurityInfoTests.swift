#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests.WindowsSecurityInfoTests {

    private func prepareProtectedDacl(
        at path: FilePath,
        followSymlink: Bool = true,
        secondaryPermission: WindowsAccessMask? = nil,
        inheritance: WindowsExplicitAccess.Inheritance = .noInheritance
    ) throws {
        let dacl = Support.makeWindowsTestDacl(
            secondaryPermission: secondaryPermission,
            inheritance: inheritance
        )
        try Support.setProtectedNativeWindowsDacl(dacl, at: path, followSymlink: followSymlink)
    }

}



extension FileSystemAPITests.MetadataTests.WindowsSecurityInfoTests {

    @Test
    func `Replacing file DACL preserves ownership`() throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(at: path)
        let securityBeforeSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        let replacementDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericRead)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(forItemAt: path, dacl: .replace(replacementDacl))

        let securityAfterSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        Support.expectWindowsAcl(securityAfterSet.dacl, matches: expectedDacl)

    }


    @Test
    func `Replacing dir DACL preserves ownership`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        try prepareProtectedDacl(at: path, inheritance: .allSubItems)
        let securityBeforeSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        let replacementDacl = Support.makeWindowsTestDacl(
            secondaryPermission: .genericRead,
            inheritance: .allSubItems
        )
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(forItemAt: path, dacl: .replace(replacementDacl))

        let securityAfterSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        Support.expectWindowsAcl(securityAfterSet.dacl, matches: expectedDacl)

    }


    @Test
    func `Removing DACL installs null DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(at: path)
        let securityBeforeSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)

        try fileSystem.setSecurityInfo(forItemAt: path, dacl: .remove)

        let securityAfterSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        #expect(securityAfterSet.dacl.state == .null)
        #expect(securityAfterSet.dacl.aces.isEmpty)

    }


    @Test
    func `No-change update preserves security`() throws {

        let path = try workspace.makeFile(at: "file")
        let securityBeforeSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)

        try fileSystem.setSecurityInfo(forItemAt: path)

        let securityAfterSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        Support.expectWindowsSecurity(securityAfterSet, matches: securityBeforeSet)

    }


    @Test
    func `Setting owner preserves group and DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(at: path)
        let securityBeforeSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        let currentOwner = try #require(securityBeforeSet.owner)
        guard 
            let replacementOwner = try Support.replacementOwner(excluding: currentOwner) 
        else {
            try Test.cancel("The current token has no alternate assignable owner")
        }

        try fileSystem.setSecurityInfo(forItemAt: path, owner: replacementOwner)

        let securityAfterSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        #expect(securityAfterSet.owner == replacementOwner.rawId)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        Support.expectWindowsAcl(securityAfterSet.dacl, matches: securityBeforeSet.dacl)

    }


    @Test
    func `Setting group preserves owner and DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(at: path)
        let securityBeforeSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        let currentGroup = try #require(securityBeforeSet.group)
        guard 
            let replacementGroup = try Support.replacementGroup(excluding: currentGroup) 
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }

        try fileSystem.setSecurityInfo(forItemAt: path, group: replacementGroup)

        let securityAfterSet = try Support.captureWindowsSecurity(at: path, followSymlink: true)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == replacementGroup.rawId)
        Support.expectWindowsAcl(securityAfterSet.dacl, matches: securityBeforeSet.dacl)

    }


    @Test
    func `Default DACL set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        try prepareProtectedDacl(at: target, secondaryPermission: .genericRead)
        try prepareProtectedDacl(at: link, followSymlink: false, secondaryPermission: .genericWrite)
        let linkSecurityBeforeSet = try Support.captureWindowsSecurity(at: link, followSymlink: false)
        let replacementDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericExecute)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(forItemAt: link, dacl: .replace(replacementDacl))

        let targetSecurityAfterSet = try Support.captureWindowsSecurity(at: target, followSymlink: true)
        let linkSecurityAfterSet = try Support.captureWindowsSecurity(at: link, followSymlink: false)
        Support.expectWindowsAcl(targetSecurityAfterSet.dacl, matches: expectedDacl)
        Support.expectWindowsSecurity(linkSecurityAfterSet, matches: linkSecurityBeforeSet)

    }


    @Test
    func `No-follow DACL set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        try prepareProtectedDacl(at: target, secondaryPermission: .genericRead)
        try prepareProtectedDacl(at: link, followSymlink: false, secondaryPermission: .genericWrite)
        let targetSecurityBeforeSet = try Support.captureWindowsSecurity(
            at: target,
            followSymlink: true
        )
        let replacementDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericExecute)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(
            forItemAt: link,
            dacl: .replace(replacementDacl),
            followSymlink: false
        )

        let targetSecurityAfterSet = try Support.captureWindowsSecurity(at: target, followSymlink: true)
        let linkSecurityAfterSet = try Support.captureWindowsSecurity(at: link, followSymlink: false)
        Support.expectWindowsSecurity(targetSecurityAfterSet, matches: targetSecurityBeforeSet)
        Support.expectWindowsAcl(linkSecurityAfterSet.dacl, matches: expectedDacl)

    }


    @Test
    func `No-follow DACL set handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        try prepareProtectedDacl(at: link, followSymlink: false, secondaryPermission: .genericRead)
        let replacementDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericExecute)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(
            forItemAt: link,
            dacl: .replace(replacementDacl),
            followSymlink: false
        )

        let linkSecurityAfterSet = try Support.captureWindowsSecurity(at: link, followSymlink: false)
        Support.expectWindowsAcl(linkSecurityAfterSet.dacl, matches: expectedDacl)

    }


    @Test
    func `Default DACL set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkSecurityBeforeSet = try Support.captureWindowsSecurity(at: link, followSymlink: false)

        let error = #expect(throws: PlatformError.self) {
            let replacementDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericExecute)
            try fileSystem.setSecurityInfo(forItemAt: link, dacl: .replace(replacementDacl))
        }

        let linkSecurityAfterSet = try Support.captureWindowsSecurity(at: link, followSymlink: false)
        #expect(error?.kind == .notFound)
        Support.expectWindowsSecurity(linkSecurityAfterSet, matches: linkSecurityBeforeSet)

    }


    @Test
    func `Setting security for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            let replacementDacl = Support.makeWindowsTestDacl(secondaryPermission: .genericRead)
            try fileSystem.setSecurityInfo(forItemAt: path, dacl: .replace(replacementDacl))
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
