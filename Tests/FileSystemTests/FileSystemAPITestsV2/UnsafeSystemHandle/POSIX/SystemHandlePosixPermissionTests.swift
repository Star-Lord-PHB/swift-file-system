#if !canImport(WinSDK)

import Testing
import Foundation
import SwiftFileSystem
import PlatformCLib



extension UnsafeSystemHandleAPITests.PosixTests {

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
    func `Default creation permissions respect umask`() throws {

        let mask = try effectiveCreationMask()
        let path = workspace.path("file")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .createIfMissing)
        )

        try handle.close()

        #expect(try capturePermissions(at: path) == FilePermissions(rawValue: 0o644).intersection(mask))

    }


    @Test
    func `Custom creation permissions respect umask`() throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o760)
        let path = workspace.path("file")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .createIfMissing),
            creationPermissions: requested
        )

        try handle.close()

        #expect(try capturePermissions(at: path) == requested.intersection(mask))

    }


    @Test
    func `Creation permissions are ignored for an existing file`() throws {

        let initial = FilePermissions(rawValue: 0o640)
        let path = try workspace.makeFile(at: "file", contents: "keep")

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: initial.rawValue)],
            ofItemAtPath: path.string
        )

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .createIfMissing),
            creationPermissions: FilePermissions(rawValue: 0o777)
        )

        try handle.close()

        #expect(try capturePermissions(at: path) == initial)

    }


    @Test
    func `Creation override applies the creation permissions`() throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o700)
        let path = workspace.path("file")

        // NOTE: The semantic creation stays .never; the creation behavior and the mode argument
        // both follow the effective flags after the override injects O_CREAT.
        var options = UnsafeSystemHandle.OpenOptions(access: .writeOnly())
        options.platformCreationFlagsOverride = .posix.create

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: options,
            creationPermissions: requested
        )

        try handle.close()

        #expect(try capturePermissions(at: path) == requested.intersection(mask))

    }


    @Test
    func `A file created with empty permissions rejects reopen`() throws {

        if geteuid() == 0 {
            try Test.cancel("Root is not subject to POSIX permission checks")
        }

        let path = workspace.path("file")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .createIfMissing),
            creationPermissions: []
        )

        // The already-open descriptor is not subject to the file mode.
        let payload = Data("Hello".utf8)

        try #expect(handle.write(contentsOf: payload.bytes) == 5)
        try handle.close()

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))
        }

        #expect(error?.kind == .permissionDenied)
        #expect(error?.systemCode == .permissionDenied)

    }

}

#endif
