import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



// Failure injection shared by the removal suites. The scenarios and their assertions are the same on
// every platform; only the way an entry is made unremovable or a directory unlistable differs.
extension FileSystemAPITests.RemovalTests {

    /// Cancels when the current process is not subject to the checks the obstructions rely on: root
    /// on POSIX, or a Windows token whose privileges bypass deny ACEs. Windows is probed for real,
    /// on sacrificial entries denied the same way the fixtures are.
    static func requireObstructionsEffective(
        in workspace: Support.Workspace,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #if canImport(WinSDK)
        let deleteProbeDirectory = try workspace.makeDirectory(at: "obstruction-probe/delete")
        let deleteProbe = try workspace.makeFile(at: "obstruction-probe/delete/file")
        try denyRemovalOfChildren(in: deleteProbeDirectory, sourceLocation: sourceLocation)
        defer { restoreRemovalOfChildren(in: deleteProbeDirectory) }
        if deleteProbe.withPlatformString({ DeleteFileW($0) }) {
            try Test.cancel(
                "The current token can delete an entry that denies it",
                sourceLocation: sourceLocation
            )
        }
        let listingProbeDirectory = try workspace.makeDirectory(at: "obstruction-probe/listing")
        try denyListing(of: listingProbeDirectory, sourceLocation: sourceLocation)
        defer { restoreListing(of: listingProbeDirectory) }
        var findData = WIN32_FIND_DATAW()
        let handle = listingProbeDirectory.appending("*").withPlatformString { pattern in
            FindFirstFileW(pattern, &findData)
        }
        if let handle, handle != INVALID_HANDLE_VALUE {
            FindClose(handle)
            try Test.cancel(
                "The current token can list a directory that denies it",
                sourceLocation: sourceLocation
            )
        }
        #else
        if geteuid() == 0 {
            try Test.cancel(
                "Root is not subject to POSIX permission checks",
                sourceLocation: sourceLocation
            )
        }
        #endif
    }


    /// Makes every direct child of `directory` unremovable while the directory stays listable and
    /// its children readable. POSIX takes the write permission off the directory. Windows denies
    /// FILE_DELETE_CHILD on the directory and DELETE on each child: either right alone lets the
    /// other one delete the child.
    static func denyRemovalOfChildren(
        in directory: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #if canImport(WinSDK)
        for name in try FileManager.default.contentsOfDirectory(atPath: directory.string) {
            try setProtectedDacl(denying: .delete, at: directory.appending(name), sourceLocation: sourceLocation)
        }
        try setProtectedDacl(denying: .deleteChild, at: directory, sourceLocation: sourceLocation)
        #else
        try setPermissions(0o555, at: directory)
        #endif
    }


    /// Undoes `denyRemovalOfChildren` on `directory` and on whichever of its children still exist;
    /// call from a `defer` so the workspace can be cleaned up.
    static func restoreRemovalOfChildren(in directory: FilePath) {
        #if canImport(WinSDK)
        guard (try? Support.itemExistsNoFollow(at: directory)) == true else { return }
        try? setProtectedDacl(denying: nil, at: directory)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.string)) ?? []
        for name in names {
            try? setProtectedDacl(denying: nil, at: directory.appending(name))
        }
        #else
        try? setPermissions(0o755, at: directory)
        #endif
    }


    /// Makes `directory` unlistable. Whether it can still be removed depends on its contents.
    static func denyListing(
        of directory: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #if canImport(WinSDK)
        try setProtectedDacl(denying: .listDirectory, at: directory, sourceLocation: sourceLocation)
        #else
        try setPermissions(0o000, at: directory)
        #endif
    }


    /// Undoes `denyListing`; call from a `defer`, and before enumerating the directory in an
    /// assertion. A directory the removal took away needs nothing.
    static func restoreListing(of directory: FilePath) {
        #if canImport(WinSDK)
        guard (try? Support.itemExistsNoFollow(at: directory)) == true else { return }
        try? setProtectedDacl(denying: nil, at: directory)
        #else
        try? setPermissions(0o755, at: directory)
        #endif
    }


    /// A directory the removal enumerated but left with all its entries: reading it may push its
    /// access time.
    static var enumeratedDirectoryPolicy: Support.ItemComparisonPolicy {
        .unchanged.excluding(.accessTime)
    }


    /// A directory that lost children keeps its identity and remaining entries but not its times.
    static var survivingDirectoryPolicy: Support.ItemComparisonPolicy {
        .unchanged.excluding([.accessTime, .modificationTime, .statusChangeTime])
    }


    /// A directory whose access was restricted and restored after the snapshot: the permissions
    /// and the times a security write touches differ, and it may have lost children as well.
    static var restoredDirectoryPolicy: Support.ItemComparisonPolicy {
        .unchanged.excluding([.permissions, .accessTime, .modificationTime, .statusChangeTime])
    }


    /// A child of a restored directory: untouched on POSIX, where the mode lives on the directory
    /// alone; on Windows the directory's DACL writes propagate into the child's inherited entries
    /// and update the times a security write touches.
    static var childOfRestoredDirectoryPolicy: Support.ItemComparisonPolicy {
        #if canImport(WinSDK)
        .unchanged.excluding([.permissions, .accessTime, .statusChangeTime])
        #else
        .unchanged
        #endif
    }


    #if canImport(WinSDK)

    /// Installs a protected DACL granting everyone full control (inheritably, so children keep
    /// their access when the entry propagates) and, when given, denying `deniedRight` on the
    /// object itself.
    private static func setProtectedDacl(
        denying deniedRight: WindowsAccessMask?,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var entries = [WindowsExplicitAccess]()
        if let deniedRight {
            entries.append(.init(permission: deniedRight, accessMode: .denyAccess, trustee: .everyone))
        }
        entries.append(.init(permission: .genericAll, inheritance: .allSubItems, trustee: .everyone))
        try Support.setProtectedNativeWindowsDacl(
            WindowsRawAcl(entries: .init(entries)),
            at: path,
            followSymlink: false,
            sourceLocation: sourceLocation
        )
    }

    #else

    private static func setPermissions(_ permissions: Int, at path: FilePath) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: path.string
        )
    }

    #endif

}
