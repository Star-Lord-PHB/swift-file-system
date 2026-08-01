#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CreationTests {

    @Suite("Windows security")
    struct WindowsSecurityTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CreationTests.WindowsSecurityTests {

    private func makeSampleTargetDacl() -> WindowsRawAcl {
        .init(entries: [
            .init(permission: .init(rawValue: FILE_GENERIC_READ | FILE_GENERIC_WRITE | FILE_GENERIC_EXECUTE), trustee: .everyone)
        ])
    }


    private func makeSampleTargetSecurityDescriptor() -> WindowsAbsoluteSecurityDescriptor {
        return WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: makeSampleTargetDacl()
        )
    }


    private func makeSampleInheritableParentDacl() -> WindowsRawAcl {
        .init(entries: [
            .init(
                permission: .init(rawValue: FILE_GENERIC_READ | FILE_GENERIC_WRITE | FILE_GENERIC_EXECUTE),
                inheritance: .allSubItems,
                trustee: .everyone
            )
        ])
    }


    private func makeSampleInheritableParentSecurityDescriptor() -> WindowsAbsoluteSecurityDescriptor {
        return WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: makeSampleInheritableParentDacl()
        )
    }


    private func expectSampleTargetSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let security = try Support.ItemMetadata.captureSecurity(
            at: path,
            sourceLocation: sourceLocation
        )
        let expectedDacl = try Support.parseWindowsRawAcl(
            makeSampleTargetDacl(),
            sourceLocation: sourceLocation
        )

        #expect(
            security.permissions.isProtected,
            sourceLocation: sourceLocation
        )
        Support.expectWindowsAcl(
            security.permissions.dacl,
            matches: expectedDacl,
            sourceLocation: sourceLocation
        )
    }


    private func expectSampleInheritedSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let security = try Support.ItemMetadata.captureSecurity(
            at: path,
            sourceLocation: sourceLocation
        )
        let expectedDacl = try Support.parseWindowsRawAcl(
            makeSampleInheritableParentDacl(),
            sourceLocation: sourceLocation
        )
        let actualAce = try #require(
            security.permissions.dacl.aces.first,
            sourceLocation: sourceLocation
        )
        let expectedAce = try #require(
            expectedDacl.aces.first,
            sourceLocation: sourceLocation
        )

        #expect(security.permissions.dacl.state == .present, sourceLocation: sourceLocation)
        #expect(security.permissions.dacl.aces.count == 1, sourceLocation: sourceLocation)
        #expect(
            actualAce.flags & BYTE(INHERITED_ACE) != 0,
            sourceLocation: sourceLocation
        )
        #expect(actualAce.type == expectedAce.type, sourceLocation: sourceLocation)
        #expect(actualAce.size == expectedAce.size, sourceLocation: sourceLocation)
        #expect(
            actualAce.bytes.dropFirst(MemoryLayout<ACE_HEADER>.size)
                .elementsEqual(
                    expectedAce.bytes.dropFirst(MemoryLayout<ACE_HEADER>.size)
                ),
            sourceLocation: sourceLocation
        )
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

        let securityBeforeReplace = try Support.ItemMetadata.captureSecurity(at: path)

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

        let securityAfterReplace = try Support.ItemMetadata.captureSecurity(at: path)
        Support.expectWindowsSecurity(
            securityAfterReplace,
            matches: securityBeforeReplace
        )

    }


    @Test
    func `Creation with intermediates preserves existing dir security`() throws {

        let path = workspace.path("directory")
        try fileSystem.createDirectory(
            at: path,
            permissions: makeSampleTargetSecurityDescriptor()
        )

        let securityBeforeCreation = try Support.ItemMetadata.captureSecurity(at: path)

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

        let securityAfterCreation = try Support.ItemMetadata.captureSecurity(at: path)
        Support.expectWindowsSecurity(
            securityAfterCreation,
            matches: securityBeforeCreation
        )

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
