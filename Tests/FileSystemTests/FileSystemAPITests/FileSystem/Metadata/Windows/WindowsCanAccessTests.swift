#if canImport(WinSDK)

import CFileSystem
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Windows access checks")
    struct WindowsCanAccessTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.WindowsCanAccessTests {

    private static var fileReadAccess: WindowsAccessMask { .init(rawValue: _FILE_GENERIC_READ) }

    private static var fileWriteAccess: WindowsAccessMask { .init(rawValue: _FILE_GENERIC_WRITE) }

    private static var fileExecuteAccess: WindowsAccessMask { .init(rawValue: _FILE_GENERIC_EXECUTE) }

    private var fileReadAccess: WindowsAccessMask { Self.fileReadAccess }

    private var fileWriteAccess: WindowsAccessMask { Self.fileWriteAccess }

    private var fileExecuteAccess: WindowsAccessMask { Self.fileExecuteAccess }


    private var testMaintenanceAccess: WindowsAccessMask { [.delete, .readControl, .writeDAC] }


    private func prepareProtectedDacl(
        at path: FilePath,
        granting access: WindowsAccessMask,
        denying deniedAccess: WindowsAccessMask = [],
        followSymlink: Bool = true
    ) throws {
        var entries = [WindowsExplicitAccess]()
        if !deniedAccess.isEmpty {
            entries.append(
                WindowsExplicitAccess(
                    permission: deniedAccess,
                    accessMode: .denyAccess,
                    trustee: .everyone
                )
            )
        }
        entries.append(
            WindowsExplicitAccess(
                permission: access.union(testMaintenanceAccess),
                trustee: .everyone
            )
        )
        let dacl = WindowsRawAcl(entries: .init(entries))
        try Support.setProtectedNativeWindowsDacl(
            dacl,
            at: path,
            followSymlink: followSymlink
        )
    }

}



extension FileSystemAPITests.MetadataTests.WindowsCanAccessTests {

    @Test
    func `Default access requires read and write`() throws {

        let readOnlyPath = try workspace.makeFile(at: "read-only")
        try prepareProtectedDacl(at: readOnlyPath, granting: fileReadAccess)
        let writeOnlyPath = try workspace.makeFile(at: "write-only")
        try prepareProtectedDacl(at: writeOnlyPath, granting: fileWriteAccess)
        let readWritePath = try workspace.makeFile(at: "read-write")
        try prepareProtectedDacl(at: readWritePath, granting: [fileReadAccess, fileWriteAccess])

        #expect(try !fileSystem.canAccess(itemAt: readOnlyPath))
        #expect(try !fileSystem.canAccess(itemAt: writeOnlyPath))
        #expect(try fileSystem.canAccess(itemAt: readWritePath))

    }


    @Test(
        arguments: [
            (fileReadAccess, .read),
            (fileWriteAccess, .write),
            (fileExecuteAccess, .execute),
            (
                [fileReadAccess, fileWriteAccess, fileExecuteAccess] as WindowsAccessMask,
                [.read, .write, .execute] as FileOperationOptions.FileAccessMode
            )
        ] as [(WindowsAccessMask, FileOperationOptions.FileAccessMode)]
    )
    func `Granted file access modes return true`(
        _ grantedAccess: WindowsAccessMask,
        _ mode: FileOperationOptions.FileAccessMode
    ) throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(at: path, granting: grantedAccess)

        #expect(try fileSystem.canAccess(itemAt: path, for: mode))

    }


    @Test
    func `Deny ACE overrides allowed access`() throws {

        let path = try workspace.makeFile(at: "file")
        try prepareProtectedDacl(
            at: path,
            granting: [fileReadAccess, fileWriteAccess, fileExecuteAccess],
            denying: .execute
        )

        #expect(try fileSystem.canAccess(itemAt: path, for: .read))
        #expect(try !fileSystem.canAccess(itemAt: path, for: .execute))

    }


    @Test
    func `Dir grants read write and execute access`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        try prepareProtectedDacl(
            at: path,
            granting: [fileReadAccess, fileWriteAccess, fileExecuteAccess]
        )

        #expect(try fileSystem.canAccess(itemAt: path, for: [.read, .write, .execute]))

    }


    @Test
    func `Default access follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        try prepareProtectedDacl(at: target, granting: [])
        try prepareProtectedDacl(at: link, granting: fileReadAccess, followSymlink: false)

        #expect(try !fileSystem.canAccess(itemAt: link, for: .read))

    }


    @Test
    func `No-follow access checks symlink itself`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        try prepareProtectedDacl(at: target, granting: [])
        try prepareProtectedDacl(at: link, granting: fileReadAccess, followSymlink: false)

        #expect(try fileSystem.canAccess(itemAt: link, for: .read, followSymlink: false))

    }


    @Test
    func `No-follow access handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        try prepareProtectedDacl(
            at: link,
            granting: [fileReadAccess, fileWriteAccess, fileExecuteAccess],
            followSymlink: false
        )

        #expect(
            try fileSystem.canAccess(itemAt: link, for: [.read, .write, .execute], followSymlink: false)
        )

    }


    @Test
    func `Default access fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.canAccess(itemAt: link, for: .read)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Missing item access fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.canAccess(itemAt: path, for: .read)
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
