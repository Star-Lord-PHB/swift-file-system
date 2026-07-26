#if canImport(WinSDK)

import Foundation
import WinSDK
import Testing
import SwiftFileSystem



extension FileHandleAPITests.ReadWriteTests {

    @Suite("Windows creation security")
    struct WindowsCreationSecurityTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.ReadWriteTests.WindowsCreationSecurityTests {

    private func makeSampleDacl() -> WindowsRawAcl {
        .init(entries: [
            .init(permission: .genericAll, trustee: .everyone)
        ])
    }


    private func makeSampleSecurityDescriptor() -> WindowsAbsoluteSecurityDescriptor {
        WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: makeSampleDacl()
        )
    }


    private func makeInheritableParentDacl() -> WindowsRawAcl {
        .init(entries: [
            .init(
                permission: .genericAll,
                inheritance: .allSubItems,
                trustee: .everyone
            )
        ])
    }


    private func expectSampleSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let security = try Support.ItemMetadata.captureSecurity(
            at: path,
            sourceLocation: sourceLocation
        )
        let expectedDacl = try Support.parseWindowsRawAcl(
            makeSampleDacl(),
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


    private func expectInheritedParentAccess(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let security = try Support.ItemMetadata.captureSecurity(
            at: path,
            sourceLocation: sourceLocation
        )
        let expectedDacl = try Support.parseWindowsRawAcl(
            makeInheritableParentDacl(),
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

        #expect(
            security.permissions.dacl.state == .present,
            sourceLocation: sourceLocation
        )
        #expect(
            security.permissions.dacl.aces.count == 1,
            sourceLocation: sourceLocation
        )
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
    func `Custom descriptor applies creation security`() throws {

        let path = workspace.path("file")
        let security = makeSampleSecurityDescriptor()

        let handle = try ReadWriteFileHandle(
            forFileAt: path,
            creationPermissions: security
        )

        try handle.close()
        try expectSampleSecurity(at: path)

    }


    @Test
    func `Default creation security inherits parent access`() throws {

        let parent = try workspace.makeDirectory(at: "parent")
        let path = workspace.path("parent/file")
        let parentDacl = makeInheritableParentDacl()
        try Support.setProtectedNativeWindowsDacl(
            parentDacl,
            at: parent,
            followSymlink: false
        )

        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.close()
        try expectInheritedParentAccess(at: path)

    }


    @Test
    func `Truncate preserves existing security`() throws {

        let path = workspace.path("file")
        let initialHandle = try ReadWriteFileHandle(
            forFileAt: path,
            creationPermissions: makeSampleSecurityDescriptor()
        )
        _ = try initialHandle.write(ByteBuffer("contents".utf8))
        try initialHandle.close()
        let securityBeforeTruncate = try Support.ItemMetadata.captureSecurity(at: path)

        let replacementSecurity = WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: .init(entries: [
                .init(permission: .genericRead, trustee: .users)
            ])
        )

        let handle = try ReadWriteFileHandle(
            forFileAt: path,
            options: .editFile(truncate: true),
            creationPermissions: replacementSecurity
        )

        try handle.close()

        let securityAfterTruncate = try Support.ItemMetadata.captureSecurity(at: path)
        Support.expectWindowsSecurity(
            securityAfterTruncate,
            matches: securityBeforeTruncate
        )
        #expect(try Data(contentsOf: URL(filePath: path.string)).isEmpty)

    }

}

#endif
