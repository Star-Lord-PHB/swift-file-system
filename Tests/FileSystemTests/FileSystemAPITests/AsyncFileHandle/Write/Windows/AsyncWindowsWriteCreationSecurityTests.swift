#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.WriteTests {

    @Suite("Windows creation security")
    struct WindowsCreationSecurityTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: Parent inheritance and truncate leaving existing security alone are synchronous open
// semantics. The view-taking initializer is the async shell proper; the two borrowing
// overloads delegate to it with the descriptor's view, so each form is proven to apply once.
extension AsyncFileHandleAPITests.WriteTests.WindowsCreationSecurityTests {

    private static func makeSampleDacl() -> WindowsRawAcl {
        .init(entries: [
            .init(
                permission: .init(rawValue: FILE_GENERIC_READ | FILE_GENERIC_WRITE | FILE_GENERIC_EXECUTE),
                trustee: .everyone
            )
        ])
    }


    private static func makeSampleSecurityDescriptor() -> WindowsAbsoluteSecurityDescriptor {
        WindowsAbsoluteSecurityDescriptor(
            control: .daclProtected,
            dacl: .acl(makeSampleDacl())
        )
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
            Self.makeSampleDacl(),
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


    @Test
    func `Descriptor view applies creation security`() async throws {

        let path = workspace.path("file")
        let security = Self.makeSampleSecurityDescriptor()
        let executor = AsyncFileSystemExecutor(label: "write-sd", maximumThreadCount: 1)

        let handle = try await AsyncWriteFileHandle(
            forFileAt: path,
            creationPermissions: security.view,
            executor: executor
        )

        #expect(handle.executor === executor)

        try await handle.close()
        try expectSampleSecurity(at: path)

    }


    @Test
    func `Absolute descriptor applies creation security`() async throws {

        let path = workspace.path("file")
        let security = Self.makeSampleSecurityDescriptor()

        let handle = try await AsyncWriteFileHandle(forFileAt: path, creationPermissions: security)

        try await handle.close()
        try expectSampleSecurity(at: path)

    }


    @Test
    func `Self-relative descriptor applies creation security`() async throws {

        let path = workspace.path("file")
        let security = Self.makeSampleSecurityDescriptor().makeSelfRelative()

        let handle = try await AsyncWriteFileHandle(forFileAt: path, creationPermissions: security)

        try await handle.close()
        try expectSampleSecurity(at: path)

    }


    @Test
    func `Pre-cancelled descriptor open reports cancellation before creating`() async throws {

        let path = workspace.path("file")

        await Support.expectPreCancelled {
            let security = Self.makeSampleSecurityDescriptor()
            _ = try await AsyncWriteFileHandle(forFileAt: path, creationPermissions: security.view)
        }

        try Support.expectItemNotExistNoFollow(at: path)

    }

}

#endif
