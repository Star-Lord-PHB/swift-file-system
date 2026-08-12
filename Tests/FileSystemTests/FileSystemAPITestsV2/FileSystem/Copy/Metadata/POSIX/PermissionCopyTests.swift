#if !canImport(WinSDK)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("POSIX permissions")
    struct PermissionCopyTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: There is no expected-success test for preserving ownership — the copy deliberately
// does not copy owners or groups (see `Ownership is not copied`, which needs root to set
// up a foreign owner in the first place).
extension FileSystemAPITests.CopyTests.PermissionCopyTests {

    private func setFoundationPermissions(
        _ permissions: FilePermissions,
        at path: FilePath
    ) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions.rawValue)],
            ofItemAtPath: path.string
        )
    }


    private func capturePermissions(at path: FilePath) throws -> FilePermissions {
        try Support.ItemMetadata.captureSecurity(at: path).permissions
    }


    // 0o666 proves the final permission write: with any common umask the destination
    // file cannot have been created with the group/other write bits already set.
    @Test(arguments: [FilePermissions(rawValue: 0o600), FilePermissions(rawValue: 0o666)])
    func `Copies exact file permissions`(permissions: FilePermissions) throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        try setFoundationPermissions(permissions, at: src)
        let dst = workspace.path("dst.txt")

        try fileSystem.copyItem(at: src, to: dst)

        #expect(try capturePermissions(at: dst) == permissions)

    }


    @Test
    func `Copies a setuid file mode`() throws {

        // The kernel drops the setuid bit when the destination is created; the final
        // permission write restores it. Only the final state is asserted here — the
        // absence of a set-id intermediate state is an implementation-order property.
        let permissions = FilePermissions(rawValue: 0o4755)
        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        try setFoundationPermissions(permissions, at: src)
        let dst = workspace.path("dst.txt")

        try fileSystem.copyItem(at: src, to: dst)

        #expect(try capturePermissions(at: dst) == permissions)

    }


    @Test
    func `Copies exact directory permissions`() throws {

        // 0o777 proves the explicit chmod after mkdir: the umask would filter the
        // group/other write bits at creation.
        let permissions = FilePermissions(rawValue: 0o777)
        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "contents")
            ]
        )
        try setFoundationPermissions(permissions, at: src)
        let dst = workspace.path("dst")

        try fileSystem.copyItem(at: src, to: dst)

        #expect(try capturePermissions(at: dst) == permissions)

    }


    @Test
    func `Copies an r-x source tree with exact final modes`() throws {

        // Companion of `Copies a read-only source tree with exact final modes` in the
        // Directory suite, which pins the owner-only 0o500 variant.
        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "file contents"),
                "sub": [
                    "nested.txt": .file(contents: "nested contents")
                ],
            ]
        )
        let dst = workspace.path("dst")
        try setFoundationPermissions(.init(rawValue: 0o444), at: src.appending("file.txt"))
        try setFoundationPermissions(.init(rawValue: 0o555), at: src.appending("sub"))
        try setFoundationPermissions(.init(rawValue: 0o555), at: src)
        // The copied directories end up write-protected as well; restore everything so
        // the workspace can be cleaned up even when an assertion fails.
        defer {
            for path in [src, src.appending("sub"), dst, dst.appending("sub")] {
                try? setFoundationPermissions(.init(rawValue: 0o755), at: path)
            }
        }
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `Preserves a symlink's own times`() throws {

        let target = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        try Support.ageAccessTime(at: link)
        let linkTimes = try Support.ItemMetadata.Times.capture(at: link)
        let dst = workspace.path("dst-link")

        try fileSystem.copyItem(at: link, to: dst)

        // The written times are the link's own, set without following it.
        let dstTimes = try Support.ItemMetadata.Times.capture(at: dst)
        #expect(dstTimes.access == linkTimes.access)
        #expect(dstTimes.modification == linkTimes.modification)

    }


    #if canImport(Darwin) || os(FreeBSD)
    @Test
    func `Preserves a symlink's own mode`() throws {

        // NOTE: Linux symlinks have no permissions of their own; the copy silently
        // skips the chmod there (pinned by the Metadata/Linux group).
        let target = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let permissions = FilePermissions(rawValue: 0o700)
        try #require(link.withPlatformString { lchmod($0, permissions.rawValue) } == 0)
        let dst = workspace.path("dst-link")

        try fileSystem.copyItem(at: link, to: dst)

        #expect(try capturePermissions(at: dst) == permissions)

    }
    #endif


    @Test
    func `Ownership is not copied`() throws {

        // NOTE: This pins the current design decision; ownership copying may become a
        // supported (possibly opt-in) behavior in the future, which would revisit this.

        // Only root can hand the source to another owner, so this runs in the Linux
        // test container and cancels elsewhere.
        if geteuid() != 0 {
            try Test.cancel("Requires root to give the source file a foreign owner")
        }
        guard let foreignUser = getpwnam("nobody") else {
            try Test.cancel("No 'nobody' user to give the source file to")
        }
        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let chownResult = src.withPlatformString {
            chown($0, foreignUser.pointee.pw_uid, foreignUser.pointee.pw_gid)
        }
        try #require(chownResult == 0)
        let dst = workspace.path("dst.txt")

        try fileSystem.copyItem(at: src, to: dst)

        let ownership = try Support.ItemMetadata.captureSecurity(at: dst).ownership
        #expect(ownership.owner.rawId == geteuid())
        #expect(ownership.owner.rawId != foreignUser.pointee.pw_uid)

    }

}

#endif
