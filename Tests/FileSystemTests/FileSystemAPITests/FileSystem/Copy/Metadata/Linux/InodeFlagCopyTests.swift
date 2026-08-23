#if canImport(Glibc) || canImport(Musl)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Linux inode flags")
    struct InodeFlagCopyTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.InodeFlagCopyTests {

    /// Sets the flags without recording an issue on failure, for capability probing
    /// and non-throwing cleanup.
    private func trySetNativeInodeFlags(_ flags: LinuxInodeFlags, at path: FilePath) -> Bool {
        let descriptor = path.withPlatformString { open($0, O_RDONLY | O_CLOEXEC) }
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        var rawFlags = flags.rawValue
        return ioctl(descriptor, _FS_IOC_SETFLAGS, &rawFlags) == 0
    }


    /// Inserts `flag` into the item's current flags, cancelling the test when the
    /// filesystem does not support inode flags or the process lacks the capability
    /// (the copy treats flags as best effort, so unsupported is not a failure).
    private func insertFlagOrCancel(
        _ flag: LinuxInodeFlags,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var flags = try Support.captureNativeInodeFlags(at: path, sourceLocation: sourceLocation)
        flags.insert(flag)
        if !trySetNativeInodeFlags(flags, at: path) {
            try Test.cancel(
                "Cannot set the inode flag on this filesystem",
                sourceLocation: sourceLocation
            )
        }
    }


    /// Removes the immutable flag, ignoring failures; an immutable item blocks the
    /// workspace cleanup.
    private func clearImmutableFlag(at path: FilePath) {
        let descriptor = path.withPlatformString { open($0, O_RDONLY | O_CLOEXEC) }
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        var rawFlags: PlatformInteropTypes.PosixInodeFlags = 0
        guard ioctl(descriptor, _FS_IOC_GETFLAGS, &rawFlags) == 0 else { return }
        var flags = LinuxInodeFlags(rawValue: rawFlags)
        flags.remove(.immutable)
        rawFlags = flags.rawValue
        _ = ioctl(descriptor, _FS_IOC_SETFLAGS, &rawFlags)
    }


    @Test
    func `Preserves the noDump flag of a file`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        try insertFlagOrCancel(.noDump, at: src)
        let dst = workspace.path("dst.txt")

        try fileSystem.copyItem(at: src, to: dst)

        #expect(try Support.captureNativeInodeFlags(at: dst).contains(.noDump))

    }


    @Test
    func `Preserves the noDump flag of a directory`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "contents")
            ]
        )
        try insertFlagOrCancel(.noDump, at: src)
        let dst = workspace.path("dst")

        try fileSystem.copyItem(at: src, to: dst)

        #expect(try Support.captureNativeInodeFlags(at: dst).contains(.noDump))

    }


    @Test
    func `Preserves the immutable flag`() throws {

        // Setting FS_IMMUTABLE_FL requires CAP_LINUX_IMMUTABLE, which even root inside
        // the test container usually lacks; the probe cancels in that case.
        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let dst = workspace.path("dst.txt")
        defer {
            clearImmutableFlag(at: src)
            clearImmutableFlag(at: dst)
        }
        try insertFlagOrCancel(.immutable, at: src)

        try fileSystem.copyItem(at: src, to: dst)

        // Like BSD uchg, the flags are written last, after the rename.
        #expect(try Support.captureNativeInodeFlags(at: dst).contains(.immutable))

    }


    @Test
    func `Copies a symlink without flag or permission errors`() throws {

        // NOTE: Linux-specific pin — symlinks carry no inode flags, and Linux does not
        // support chmod on a symlink either; the copy skips both silently instead of
        // reporting per-item errors. The times themselves are asserted by the POSIX
        // permission group's symlink test.
        let target = try workspace.makeFile(at: "target.txt", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let dst = workspace.path("dst-link")

        let report = fileSystem.copyItem(at: link, to: dst, errorStrategy: .collectAndReturn)

        #expect(report == nil)
        try Support.expectItemExistNoFollow(at: dst)

    }

}

#endif
