import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem

/// Environment capability checks that cancel the test when a capability it needs is absent.
///
/// Where it can, a check exercises the capability natively, independent of the library under
/// test, right where the test is about to use it, so it sees the same file system and access
/// policy as the test itself; the others look up the process identity, the identities available
/// to it, or an API's presence. A failure that does not mean "absent" fails the test instead.
extension FileSystemTestSupport {

    #if !canImport(WinSDK)
    /// Cancels the test when a FIFO cannot be created at `path`.
    ///
    /// The check creates the FIFO and removes it again, so `path` must not exist yet. EACCES and
    /// EPERM mean the environment does not allow FIFOs there (Android's SELinux policy denies the
    /// adb shell domain creating them under `/data/local/tmp`).
    static func requireFifoCreationAvailable(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        if path.withPlatformString({ mkfifo($0, 0o644) }) == 0 {
            try #require(
                path.withPlatformString { unlink($0) } == 0,
                "Removing the probe FIFO failed with errno \(errno)",
                sourceLocation: sourceLocation
            )
            return
        }
        try #require(
            errno == EACCES || errno == EPERM,
            "mkfifo failed with errno \(errno)",
            sourceLocation: sourceLocation
        )
        try Test.cancel(
            "Creating a FIFO is not permitted here (errno \(errno))",
            sourceLocation: sourceLocation
        )
    }
    #endif


    /// Cancels the test when a hard link to the item at `existingPath` cannot be created at `path`.
    ///
    /// The check links the item itself without following a symlink, as `createHardLink(at:for:)`
    /// does, and removes the link again, so `path` must not exist yet. Access denials and file
    /// systems without hard links mean the capability is absent (Android's SELinux policy never
    /// allows the adb shell domain or apps to create hard links).
    static func requireHardLinkCreationAvailable(
        at path: FilePath,
        for existingPath: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #if canImport(WinSDK)
        let created = path.withPlatformString { linkPointer in
            existingPath.withPlatformString { CreateHardLinkW(linkPointer, $0, nil) }
        }
        if created {
            try #require(
                path.withPlatformString { DeleteFileW($0) },
                "Removing the probe link failed with error \(GetLastError())",
                sourceLocation: sourceLocation
            )
            return
        }
        let error = GetLastError()
        // Access denied, or a volume without hard links (FAT and exFAT report an invalid function).
        let absent = [ERROR_ACCESS_DENIED, ERROR_INVALID_FUNCTION, ERROR_NOT_SUPPORTED].map { DWORD($0) }
        try #require(
            absent.contains(error),
            "CreateHardLinkW failed with error \(error)",
            sourceLocation: sourceLocation
        )
        try Test.cancel(
            "Creating a hard link is not permitted here (error \(error))",
            sourceLocation: sourceLocation
        )
        #else
        let result = path.withPlatformString { linkPointer in
            existingPath.withPlatformString { linkat(AT_FDCWD, $0, AT_FDCWD, linkPointer, 0) }
        }
        if result == 0 {
            try #require(
                path.withPlatformString { unlink($0) } == 0,
                "Removing the probe link failed with errno \(errno)",
                sourceLocation: sourceLocation
            )
            return
        }
        // ENOTSUP: Darwin file systems that refuse linking a symlink itself.
        try #require(
            errno == EACCES || errno == EPERM || errno == ENOTSUP,
            "linkat failed with errno \(errno)",
            sourceLocation: sourceLocation
        )
        try Test.cancel(
            "Creating a hard link is not permitted here (errno \(errno))",
            sourceLocation: sourceLocation
        )
        #endif
    }


    /// Cancels the test when the file system at `directory` rejects names that are not valid
    /// Unicode (see ``nonUnicodeName(_:)``).
    ///
    /// The check creates a directory with such a name in `directory` and removes it again. APFS
    /// rejects these names with EILSEQ; NTFS and byte-oriented file systems such as ext4 store them.
    static func requireNonUnicodeNamesAvailable(
        in directory: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let probe = directory.appending(nonUnicodeName("non-unicode-probe"))
        #if canImport(WinSDK)
        if probe.withPlatformString({ CreateDirectoryW($0, nil) }) {
            try #require(
                probe.withPlatformString { RemoveDirectoryW($0) },
                "Removing the probe directory failed with error \(GetLastError())",
                sourceLocation: sourceLocation
            )
            return
        }
        let error = GetLastError()
        try #require(
            error == DWORD(ERROR_INVALID_NAME),
            "CreateDirectoryW failed with error \(error)",
            sourceLocation: sourceLocation
        )
        try Test.cancel(
            "The file system rejects names that are not valid Unicode (error \(error))",
            sourceLocation: sourceLocation
        )
        #else
        if probe.withPlatformString({ mkdir($0, 0o755) }) == 0 {
            try #require(
                probe.withPlatformString { rmdir($0) } == 0,
                "Removing the probe directory failed with errno \(errno)",
                sourceLocation: sourceLocation
            )
            return
        }
        try #require(
            errno == EILSEQ,
            "mkdir failed with errno \(errno)",
            sourceLocation: sourceLocation
        )
        try Test.cancel(
            "The file system rejects names that are not valid Unicode (errno \(errno))",
            sourceLocation: sourceLocation
        )
        #endif
    }


    /// Cancels the test when the attribute query of the item at `path` does not report
    /// `attributes` as supported, so the test could not observe them there.
    ///
    /// Only Linux and Android can lack them: statx reports the supported attributes per file
    /// system, and none where statx is not used (kernels before 4.11, and Android before API 30,
    /// where the statx shim falls back to `fstatat`).
    static func requireAttributeQueryAvailable(
        for attributes: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let captured = try ItemMetadata.captureAttributes(at: path, sourceLocation: sourceLocation)
        if !captured.supported.isSuperset(of: attributes) {
            try Test.cancel(
                "The attribute query does not report \(attributes) here",
                sourceLocation: sourceLocation
            )
        }
    }


    /// Cancels the test when reads on `workspace`'s volume do not push access times forward (a
    /// `noatime` mount, or NTFS with last-access updates disabled), so the test could neither
    /// observe that push nor prove it was undone.
    ///
    /// The probe file sits at a fixed path in the workspace, so call this at most once per
    /// workspace.
    static func requireAccessTimeUpdatesOnRead(
        in workspace: Workspace,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        if try !volumeUpdatesAccessTimeOnRead(in: workspace, sourceLocation: sourceLocation) {
            try Test.cancel(
                "The volume does not update access times on read",
                sourceLocation: sourceLocation
            )
        }
    }


    /// Returns a group other than `excludedGroup` that the current process may give an item,
    /// cancelling the test when there is none.
    static func requireReplacementGroup(
        excluding excludedGroup: PlatformIdentity.RawID,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> PlatformIdentity {
        if let group = try replacementGroup(excluding: excludedGroup, sourceLocation: sourceLocation) {
            return group
        }
        #if canImport(WinSDK)
        try Test.cancel(
            "The current token has no alternate enabled group",
            sourceLocation: sourceLocation
        )
        #else
        try Test.cancel(
            "No alternate group is available to the current process",
            sourceLocation: sourceLocation
        )
        #endif
    }


    #if canImport(WinSDK)
    /// Returns an owner other than `excludedOwner` that the current token may assign, cancelling
    /// the test when there is none.
    static func requireReplacementOwner(
        excluding excludedOwner: WindowsSid,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> PlatformIdentity {
        if let owner = try replacementOwner(excluding: excludedOwner, sourceLocation: sourceLocation) {
            return owner
        }
        try Test.cancel(
            "The current token has no alternate assignable owner",
            sourceLocation: sourceLocation
        )
    }


    /// Cancels the test when the current token can still list the directory at `path` despite the
    /// deny ACE installed on it (for example a token with enabled backup privileges).
    static func requireListingDenied(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var findData = WIN32_FIND_DATAW()
        let handle = path.appending("*").withPlatformString { pattern in
            FindFirstFileW(pattern, &findData)
        }
        if let handle, handle != INVALID_HANDLE_VALUE {
            FindClose(handle)
            try Test.cancel(
                "The current token is not subject to the installed deny ACE",
                sourceLocation: sourceLocation
            )
        }
    }


    /// Cancels the test when `GetFileInformationByName` is unavailable; it arrived with
    /// Windows 11 24H2 and Windows Server 2025.
    static func requireFileInformationByNameAvailable(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        if getGetFileInformationByNameFuncPtr() == nil {
            try Test.cancel(
                "GetFileInformationByName is unavailable on this system",
                sourceLocation: sourceLocation
            )
        }
    }
    #else
    /// Cancels the test when the process is not subject to POSIX permission checks, so a denial
    /// the test sets up would not take effect: root bypasses the permission bits.
    static func requirePermissionChecksEnforced(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        if geteuid() == 0 {
            try Test.cancel(
                "Root is not subject to POSIX permission checks",
                sourceLocation: sourceLocation
            )
        }
    }
    #endif


    #if os(Linux) || os(Android)
    /// Cancels the test when `flag` cannot be set on the item at `path`: its file system has no
    /// inode flags or not this one, or the process may not set it (the immutable and append-only
    /// flags need CAP_LINUX_IMMUTABLE, which even root in a container usually lacks).
    ///
    /// The check sets the flag and restores the previous flags, which moves the item's ctime, so
    /// it goes before any snapshot of the item.
    static func requireInodeFlagSettable(
        _ flag: LinuxInodeFlags,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let descriptor = path.withPlatformString { open($0, O_RDONLY | O_CLOEXEC) }
        try #require(descriptor >= 0, "open failed with errno \(errno)", sourceLocation: sourceLocation)
        defer { close(descriptor) }
        var previousFlags = 0 as PlatformInteropTypes.PosixInodeFlags
        if ioctl(descriptor, FS_IOC_GETFLAGS, &previousFlags) == 0 {
            var probeFlags = LinuxInodeFlags(rawValue: previousFlags).union(flag).rawValue
            if ioctl(descriptor, FS_IOC_SETFLAGS, &probeFlags) == 0 {
                try #require(
                    ioctl(descriptor, FS_IOC_SETFLAGS, &previousFlags) == 0,
                    "Restoring the inode flags failed with errno \(errno)",
                    sourceLocation: sourceLocation
                )
                return
            }
        }
        // ENOTTY and EOPNOTSUPP: no inode flags or not this one; EPERM and EACCES: not permitted.
        try #require(
            errno == ENOTTY || errno == EOPNOTSUPP || errno == EPERM || errno == EACCES,
            "Setting the inode flag failed with errno \(errno)",
            sourceLocation: sourceLocation
        )
        try Test.cancel(
            "The inode flag cannot be set here (errno \(errno))",
            sourceLocation: sourceLocation
        )
    }


    /// Cancels the test when the procfs file at `path` is missing or unreadable, as when procfs is
    /// not mounted or its policy hides the file from the process.
    static func requireProcfsFileReadable(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let descriptor = path.withPlatformString { open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW) }
        if descriptor >= 0 {
            close(descriptor)
            return
        }
        try #require(
            errno == ENOENT || errno == EACCES,
            "open failed with errno \(errno)",
            sourceLocation: sourceLocation
        )
        try Test.cancel("\(path) is not readable here (errno \(errno))", sourceLocation: sourceLocation)
    }
    #endif

}
