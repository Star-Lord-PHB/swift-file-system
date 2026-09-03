#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.ReadWriteTests {

    @Suite("POSIX creation permissions")
    struct POSIXCreationPermissionTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: Default permissions, the umask intersection itself and truncate leaving existing
// permissions alone are synchronous open semantics; only the forwarding of the
// creation-permissions argument through the async shell is discriminated here.
extension AsyncFileHandleAPITests.ReadWriteTests.POSIXCreationPermissionTests {

    private func effectiveCreationMask() throws -> FilePermissions {
        let probe = workspace.path("creation-mask-probe")
        let result = probe.withPlatformString { path in
            mkdir(path, mode_t(0o777))
        }
        try #require(
            result == 0,
            "Failed to create permission probe with errno \(errno)"
        )
        return try capturePermissions(at: probe)
    }


    private func capturePermissions(at path: FilePath) throws -> FilePermissions {
        try Support.ItemMetadata.captureSecurity(at: path).permissions
    }


    @Test
    func `Custom creation permissions respect umask`() async throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o760)
        let path = workspace.path("file")

        let handle = try await AsyncReadWriteFileHandle(forFileAt: path, creationPermissions: requested)

        try await handle.close()

        #expect(try capturePermissions(at: path) == requested.intersection(mask))

    }

}

#endif
