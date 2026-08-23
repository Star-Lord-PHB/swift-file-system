#if canImport(WinSDK)

import CFileSystem
import Testing
import SwiftFileSystem


private var byNameFileInfoAvailable: Bool { getGetFileInformationByNameFuncPtr() != nil }


extension FileSystemAPITests.MetadataTests {

    /// Pins the `getSecurityInfo` → `WindowsAccessChecker` pipeline against the kernel's
    /// own evaluation of the caller's effective access (`FILE_STAT_INFORMATION`'s
    /// `EffectiveAccess`, the only oracle that is independent of the Authz machinery).
    /// This also polices the token-based context of `effectiveAccessMaskForCurrentProcess`:
    /// the kernel evaluates the real process token.
    @Suite("Windows effective access")
    struct WindowsEffectiveAccessTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.WindowsEffectiveAccessTests {

    private func kernelEffectiveAccessMask(
        forItemAt path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> WindowsAccessMask {
        let getFileInfoByName = try #require(
            getGetFileInformationByNameFuncPtr(),
            sourceLocation: sourceLocation
        )
        var info = FILE_STAT_INFORMATION()
        let success = path.withPlatformString { pathPtr in
            getFileInfoByName(pathPtr, FileStatByNameInfo, &info, DWORD(MemoryLayout<FILE_STAT_INFORMATION>.size))
        }.boolValue
        try #require(
            success,
            "Failed to query kernel effective access for \(path)",
            sourceLocation: sourceLocation
        )
        return .init(rawValue: info.EffectiveAccess)
    }


    @Test(.enabled(if: byNameFileInfoAvailable))
    func `Checker matches kernel evaluation for a default file`() throws {

        let path = try workspace.makeFile(at: "file")

        let sd = try fileSystem.getSecurityInfo(forItemAt: path)
        let checkerMask = try WindowsAccessChecker().effectiveAccessMaskForCurrentProcess(whenAccessing: sd)

        let kernelMask = try kernelEffectiveAccessMask(forItemAt: path)
        #expect(checkerMask == kernelMask)

    }


    @Test(.enabled(if: byNameFileInfoAvailable))
    func `Checker matches kernel evaluation under a restrictive protected DACL`() throws {

        let grantedAccess = [
            .readData, .readAttributes, .synchronize, .delete, .readControl, .writeDAC,
        ] as WindowsAccessMask
        let path = try workspace.makeFile(at: "file")
        let restrictiveDacl = WindowsRawAcl(entries: [
            .init(permission: .writeData, accessMode: .denyAccess, trustee: .everyone),
            .init(permission: grantedAccess, trustee: .everyone),
        ])
        try Support.setProtectedNativeWindowsDacl(restrictiveDacl, at: path, followSymlink: true)

        let sd = try fileSystem.getSecurityInfo(forItemAt: path)
        let checkerMask = try WindowsAccessChecker().effectiveAccessMaskForCurrentProcess(whenAccessing: sd)

        let kernelMask = try kernelEffectiveAccessMask(forItemAt: path)
        #expect(checkerMask == kernelMask)
        #expect(checkerMask == grantedAccess)

    }

}

#endif
