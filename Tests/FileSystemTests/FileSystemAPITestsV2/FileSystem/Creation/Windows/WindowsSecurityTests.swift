#if canImport(WinSDK)

import Testing
import SwiftFileSystem



extension FileSystemAPITests.CreationTests {

    @Suite("Windows security")
    struct WindowsSecurityTests {

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CreationTests.WindowsSecurityTests {

    private func makeSampleTargetSecurityDescriptor() -> WindowsAbsoluteSecurityDescriptor {
        let dacl = WindowsRawAcl(entries: [
            .init(permission: .genericAll, trustee: .everyone)
        ])
        return WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: dacl
        )
    }


    private func makeSampleInheritableParentSecurityDescriptor() -> WindowsAbsoluteSecurityDescriptor {
        let dacl = WindowsRawAcl(entries: [
            .init(permission: .genericAll, inheritance: .allSubItems, trustee: .everyone)
        ])
        return WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: dacl
        )
    }


    private func expectSampleTargetSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let trustee = WindowsExplicitAccess.RawTrustee.everyone
        let descriptor = try FileSystem().getSecurityInfo(forItemAt: path)
        #expect(descriptor.control.control.contains(.daclProtected), sourceLocation: sourceLocation)
        try #require(descriptor.dacl.case == .present, sourceLocation: sourceLocation)

        let dacl = descriptor.dacl.value!
        try #require(dacl.aceCount == 1, sourceLocation: sourceLocation)
        let ace = dacl[0]
        #expect(!ace.flags.contains(.inherited), sourceLocation: sourceLocation)
        #expect(ace.type == .allow, sourceLocation: sourceLocation)
        #expect(ace.permission.sid.string == trustee.sid.string, sourceLocation: sourceLocation)
        #expect(ace.permission.mask == .genericAll, sourceLocation: sourceLocation)
    }


    private func expectSampleInheritedSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let trustee = WindowsExplicitAccess.RawTrustee.everyone
        let descriptor = try FileSystem().getSecurityInfo(forItemAt: path)
        #expect(descriptor.owner?.sid.string != nil, sourceLocation: sourceLocation)
        #expect(descriptor.group?.sid.string != nil, sourceLocation: sourceLocation)
        try #require(descriptor.dacl.case == .present, sourceLocation: sourceLocation)

        let dacl = descriptor.dacl.value!
        try #require(dacl.aceCount == 1, sourceLocation: sourceLocation)
        let ace = dacl[0]
        #expect(ace.flags.contains(.inherited), sourceLocation: sourceLocation)
        #expect(ace.type == .allow, sourceLocation: sourceLocation)
        #expect(ace.permission.sid.string == trustee.sid.string, sourceLocation: sourceLocation)
        #expect(ace.permission.mask == .genericAll, sourceLocation: sourceLocation)
    }


    private func expectSecurityExactEquals(
        _ actual: borrowing WindowsSelfRelativeSecurityDescriptor,
        _ expected: borrowing WindowsSelfRelativeSecurityDescriptor,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(actual.control.revision == expected.control.revision, sourceLocation: sourceLocation)
        #expect(actual.control.control == expected.control.control, sourceLocation: sourceLocation)

        #expect(actual.owner?.sid.string == expected.owner?.sid.string, sourceLocation: sourceLocation)
        #expect(actual.owner?.defaulted == expected.owner?.defaulted, sourceLocation: sourceLocation)

        #expect(actual.group?.sid.string == expected.group?.sid.string, sourceLocation: sourceLocation)
        #expect(actual.group?.defaulted == expected.group?.defaulted, sourceLocation: sourceLocation)

        #expect(actual.dacl.case == expected.dacl.case, sourceLocation: sourceLocation)
        #expect(actual.dacl.defaulted == expected.dacl.defaulted, sourceLocation: sourceLocation)

        let actualDACL = actual.dacl.value
        let expectedDACL = expected.dacl.value

        #expect(actualDACL?.revision == expectedDACL?.revision, sourceLocation: sourceLocation)
        #expect(actualDACL?.aceCount == expectedDACL?.aceCount, sourceLocation: sourceLocation)

        let aceCount = Int(min(actualDACL?.aceCount ?? 0, expectedDACL?.aceCount ?? 0))
        for index in 0 ..< aceCount {
            let actualACE = actualDACL![index]
            let expectedACE = expectedDACL![index]
            let comment = "DACL ACE at index \(index)" as Comment
            #expect(actualACE.type == expectedACE.type, comment, sourceLocation: sourceLocation)
            #expect(actualACE.flags == expectedACE.flags, comment, sourceLocation: sourceLocation)
            #expect(actualACE.size == expectedACE.size, comment, sourceLocation: sourceLocation)
            #expect(actualACE.permission.mask == expectedACE.permission.mask, comment, sourceLocation: sourceLocation)
            #expect(actualACE.permission.sid.string == expectedACE.permission.sid.string, comment, sourceLocation: sourceLocation)
        }
    }


    @Test
    func `Protected file DACL contains explicit access`() throws {

        let path = workspace.path("file")
        let security = makeSampleTargetSecurityDescriptor()

        try fileSystem.createFile(
            at: path,
            permissions: security,
            content: ByteBuffer("content".utf8)
        )

        try expectSampleTargetSecurity(at: path)

    }


    @Test
    func `Protected dir DACL contains explicit access`() throws {

        let path = workspace.path("directory")
        let security = makeSampleTargetSecurityDescriptor()

        try fileSystem.createDirectory(
            at: path,
            permissions: security
        )

        try expectSampleTargetSecurity(at: path)

    }


    @Test
    func `Custom security applies only to leaf dir`() throws {

        let parent = workspace.path("parent")
        let firstIntermediate = workspace.path("parent/a")
        let secondIntermediate = workspace.path("parent/a/b")
        let leaf = workspace.path("parent/a/b/c")
        try fileSystem.createDirectory(
            at: parent,
            permissions: makeSampleInheritableParentSecurityDescriptor()
        )

        let security = makeSampleTargetSecurityDescriptor()

        try fileSystem.createDirectory(
            at: leaf,
            withIntermediateDirectories: true,
            permissions: security
        )

        try expectSampleInheritedSecurity(at: firstIntermediate)
        try expectSampleInheritedSecurity(at: secondIntermediate)
        try expectSampleTargetSecurity(at: leaf)

    }


    @Test
    func `Replace preserves existing file security`() throws {

        let path = workspace.path("file")
        try fileSystem.createFile(
            at: path,
            permissions: makeSampleTargetSecurityDescriptor()
        )

        let securityBeforeReplace = try fileSystem.getSecurityInfo(forItemAt: path)

        let replacementSecurity = WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: .init(entries: [
                .init(permission: .genericRead, trustee: .users)
            ])
        )

        try fileSystem.createFile(
            at: path,
            replaceExisting: true,
            permissions: replacementSecurity
        )

        let securityAfterReplace = try fileSystem.getSecurityInfo(forItemAt: path)
        expectSecurityExactEquals(securityAfterReplace, securityBeforeReplace)

    }


    @Test
    func `Creation with intermediates preserves existing dir security`() throws {

        let path = workspace.path("directory")
        try fileSystem.createDirectory(
            at: path,
            permissions: makeSampleTargetSecurityDescriptor()
        )

        let securityBeforeCreation = try fileSystem.getSecurityInfo(forItemAt: path)

        let replacementSecurity = WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: .init(entries: [
                .init(permission: .genericRead, trustee: .users)
            ])
        )

        try fileSystem.createDirectory(
            at: path,
            withIntermediateDirectories: true,
            permissions: replacementSecurity
        )

        let securityAfterCreation = try fileSystem.getSecurityInfo(forItemAt: path)
        expectSecurityExactEquals(securityAfterCreation, securityBeforeCreation)

    }


    @Test
    func `Default file security inherits parent access`() throws {

        let parent = workspace.path("parent")
        let file = workspace.path("parent/file")
        let parentSecurity = makeSampleInheritableParentSecurityDescriptor()
        try fileSystem.createDirectory(
            at: parent,
            permissions: parentSecurity
        )

        try fileSystem.createFile(at: file)

        try expectSampleInheritedSecurity(at: file)

    }


    @Test
    func `Default dir security inherits parent access`() throws {

        let parent = workspace.path("parent")
        let directory = workspace.path("parent/directory")
        let parentSecurity = makeSampleInheritableParentSecurityDescriptor()
        try fileSystem.createDirectory(
            at: parent,
            permissions: parentSecurity
        )

        try fileSystem.createDirectory(at: directory)

        try expectSampleInheritedSecurity(at: directory)

    }

}

#endif
