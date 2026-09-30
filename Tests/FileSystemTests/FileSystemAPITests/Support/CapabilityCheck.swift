import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem

/// Environment capability checks that cancel the test when a capability it needs is absent.
///
/// Each check exercises the capability natively, independent of the library under test, right
/// where the test is about to use it, so it sees the same file system and access policy as the
/// test itself. A failure that does not mean "absent" fails the test instead.
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

}
