#if !canImport(WinSDK)

import Foundation
import SystemPackage
import Testing
import SwiftFileSystem

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif



extension FileHandleAPITests.WriteTests {

    @Suite("POSIX creation permissions")
    struct POSIXCreationPermissionTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.WriteTests.POSIXCreationPermissionTests {

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

        let handle = try WriteFileHandle(forFileAt: path)

        try handle.close()

        #expect(try capturePermissions(at: path) == .init(rawValue: 0o644).intersection(mask))

    }


    @Test
    func `Custom creation permissions respect umask`() throws {

        let mask = try effectiveCreationMask()
        let requested = FilePermissions(rawValue: 0o760)
        let path = workspace.path("file")

        let handle = try WriteFileHandle(
            forFileAt: path,
            creationPermissions: requested
        )

        try handle.close()

        #expect(try capturePermissions(at: path) == requested.intersection(mask))

    }


    @Test
    func `Truncate preserves existing permissions`() throws {

        let initial = FilePermissions(rawValue: 0o640)
        let requested = FilePermissions(rawValue: 0o777)
        let path = try workspace.makeFile(at: "file", contents: "contents")
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: initial.rawValue)],
            ofItemAtPath: path.string
        )

        let handle = try WriteFileHandle(
            forFileAt: path,
            options: .editFile(truncate: true),
            creationPermissions: requested
        )

        try handle.close()

        #expect(try capturePermissions(at: path) == initial)
        #expect(try Data(contentsOf: URL(filePath: path.string)).isEmpty)

    }

}

#endif
