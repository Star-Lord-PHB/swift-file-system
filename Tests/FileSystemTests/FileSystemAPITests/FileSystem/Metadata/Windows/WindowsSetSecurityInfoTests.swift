#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests.WindowsSecurityInfoTests {

    private func captureSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Support.ItemMetadata.Security {
        try Support.ItemMetadata.captureSecurity(
            at: path,
            sourceLocation: sourceLocation
        )
    }


    private func prepareProtectedDacl(
        at path: FilePath,
        followSymlink: Bool = true,
        secondaryPermission: WindowsAccessMask? = nil,
        inheritance: WindowsExplicitAccess.Inheritance = .noInheritance
    ) throws {
        let dacl = makeWindowsTestDacl(
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
        let securityBeforeSet = try captureSecurity(at: path)
        let replacementDacl = makeWindowsTestDacl(secondaryPermission: fileGenericReadAccessMask)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(forItemAt: path, dacl: .replace(replacementDacl))

        let securityAfterSet = try captureSecurity(at: path)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        Support.expectWindowsAcl(
            securityAfterSet.permissions.dacl,
            matches: expectedDacl
        )

    }


    @Test
    func `Replacing dir DACL preserves ownership`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        try prepareProtectedDacl(at: path, inheritance: .allSubItems)
        let securityBeforeSet = try captureSecurity(at: path)
        let replacementDacl = makeWindowsTestDacl(
            secondaryPermission: fileGenericReadAccessMask,
            inheritance: .allSubItems
        )
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(forItemAt: path, dacl: .replace(replacementDacl))

        let securityAfterSet = try captureSecurity(at: path)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        Support.expectWindowsAcl(
            securityAfterSet.permissions.dacl,
            matches: expectedDacl
        )

    }


    @Test
    func `Removing DACL installs null DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(at: path)
        let securityBeforeSet = try captureSecurity(at: path)

        try fileSystem.setSecurityInfo(forItemAt: path, dacl: .remove)

        let securityAfterSet = try captureSecurity(at: path)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        #expect(securityAfterSet.permissions.dacl.state == .null)
        #expect(securityAfterSet.permissions.dacl.aces.isEmpty)

    }


    @Test
    func `No-change update preserves security`() throws {

        let path = try workspace.makeFile(at: "file")
        let securityBeforeSet = try captureSecurity(at: path)

        try fileSystem.setSecurityInfo(forItemAt: path)

        let securityAfterSet = try captureSecurity(at: path)
        Support.expectWindowsSecurity(securityAfterSet, matches: securityBeforeSet)

    }


    @Test
    func `Setting owner preserves group and DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(at: path)
        let securityBeforeSet = try captureSecurity(at: path)
        guard 
            let replacementOwner = try Support.replacementOwner(
                excluding: securityBeforeSet.owner.rawId
            )
        else {
            try Test.cancel("The current token has no alternate assignable owner")
        }

        try fileSystem.setSecurityInfo(forItemAt: path, owner: replacementOwner)

        let securityAfterSet = try captureSecurity(at: path)
        #expect(securityAfterSet.owner == replacementOwner)
        #expect(securityAfterSet.group == securityBeforeSet.group)
        Support.expectWindowsAcl(
            securityAfterSet.permissions.dacl,
            matches: securityBeforeSet.permissions.dacl
        )

    }


    @Test
    func `Setting group preserves owner and DACL`() throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(at: path)
        let securityBeforeSet = try captureSecurity(at: path)
        guard 
            let replacementGroup = try Support.replacementGroup(
                excluding: securityBeforeSet.group.rawId
            )
        else {
            try Test.cancel("The current token has no alternate enabled group")
        }

        try fileSystem.setSecurityInfo(forItemAt: path, group: replacementGroup)

        let securityAfterSet = try captureSecurity(at: path)
        #expect(securityAfterSet.owner == securityBeforeSet.owner)
        #expect(securityAfterSet.group == replacementGroup)
        Support.expectWindowsAcl(
            securityAfterSet.permissions.dacl,
            matches: securityBeforeSet.permissions.dacl
        )

    }


    @Test
    func `Default DACL set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        try prepareProtectedDacl(at: target, secondaryPermission: fileGenericReadAccessMask)
        try prepareProtectedDacl(at: link, followSymlink: false, secondaryPermission: fileGenericWriteAccessMask)
        let linkSecurityBeforeSet = try captureSecurity(at: link)
        let replacementDacl = makeWindowsTestDacl(secondaryPermission: fileGenericExecuteAccessMask)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(forItemAt: link, dacl: .replace(replacementDacl))

        let targetSecurityAfterSet = try captureSecurity(at: target)
        let linkSecurityAfterSet = try captureSecurity(at: link)
        Support.expectWindowsAcl(
            targetSecurityAfterSet.permissions.dacl,
            matches: expectedDacl
        )
        Support.expectWindowsSecurity(linkSecurityAfterSet, matches: linkSecurityBeforeSet)

    }


    @Test
    func `No-follow DACL set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        try prepareProtectedDacl(at: target, secondaryPermission: fileGenericReadAccessMask)
        try prepareProtectedDacl(at: link, followSymlink: false, secondaryPermission: fileGenericWriteAccessMask)
        let targetSecurityBeforeSet = try captureSecurity(at: target)
        let replacementDacl = makeWindowsTestDacl(secondaryPermission: fileGenericExecuteAccessMask)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(
            forItemAt: link,
            dacl: .replace(replacementDacl),
            followSymlink: false
        )

        let targetSecurityAfterSet = try captureSecurity(at: target)
        let linkSecurityAfterSet = try captureSecurity(at: link)
        Support.expectWindowsSecurity(targetSecurityAfterSet, matches: targetSecurityBeforeSet)
        Support.expectWindowsAcl(
            linkSecurityAfterSet.permissions.dacl,
            matches: expectedDacl
        )

    }


    @Test
    func `No-follow DACL set handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        try prepareProtectedDacl(at: link, followSymlink: false, secondaryPermission: fileGenericReadAccessMask)
        let replacementDacl = makeWindowsTestDacl(secondaryPermission: fileGenericExecuteAccessMask)
        let expectedDacl = try Support.parseWindowsRawAcl(replacementDacl)

        try fileSystem.setSecurityInfo(
            forItemAt: link,
            dacl: .replace(replacementDacl),
            followSymlink: false
        )

        let linkSecurityAfterSet = try captureSecurity(at: link)
        Support.expectWindowsAcl(
            linkSecurityAfterSet.permissions.dacl,
            matches: expectedDacl
        )

    }


    @Test
    func `Default DACL set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkSecurityBeforeSet = try captureSecurity(at: link)

        let error = #expect(throws: PlatformError.self) {
            let replacementDacl = makeWindowsTestDacl(secondaryPermission: .genericExecute)
            try fileSystem.setSecurityInfo(forItemAt: link, dacl: .replace(replacementDacl))
        }

        let linkSecurityAfterSet = try captureSecurity(at: link)
        #expect(error?.kind == .notFound)
        Support.expectWindowsSecurity(linkSecurityAfterSet, matches: linkSecurityBeforeSet)

    }


    @Test
    func `Setting security for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            let replacementDacl = makeWindowsTestDacl(secondaryPermission: .genericRead)
            try fileSystem.setSecurityInfo(forItemAt: path, dacl: .replace(replacementDacl))
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
