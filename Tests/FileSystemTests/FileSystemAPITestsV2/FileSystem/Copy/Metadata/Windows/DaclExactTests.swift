#if canImport(WinSDK)

import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Windows DACL exact")
    struct DaclExactTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// `windowsPreserveExactDacl` writes the source security descriptor verbatim (backup
// semantics, like robocopy /COPYALL). The assertions compare full DACL SDDL strings,
// which include the ACE list, its order, the protection flag, and the auto-inherited
// bookkeeping flag ("AI" — carried across the non-propagating write by injecting
// `SE_DACL_AUTO_INHERIT_REQ` when the source has it).
extension FileSystemAPITests.CopyTests.DaclExactTests {

    private var exactDaclOptions: FileOperationOptions.CopyItemOptions {
        .init(windowsPreserveExactDacl: true)
    }


    private var fileGenericReadAccessMask: WindowsAccessMask {
        .init(rawValue: FILE_GENERIC_READ)
    }

    private var fileGenericWriteAccessMask: WindowsAccessMask {
        .init(rawValue: FILE_GENERIC_WRITE)
    }

    private var fileGenericExecuteAccessMask: WindowsAccessMask {
        .init(rawValue: FILE_GENERIC_EXECUTE)
    }


    /// A protected-DACL payload that still lets the test read, copy, and delete the
    /// item it is applied to.
    private func makeSampleDacl(
        secondaryPermission: WindowsAccessMask? = nil,
        inheritance: WindowsExplicitAccess.Inheritance = .noInheritance
    ) -> WindowsRawAcl {
        var entries = [
            WindowsExplicitAccess(
                permission: [
                    fileGenericReadAccessMask,
                    fileGenericWriteAccessMask,
                    fileGenericExecuteAccessMask,
                ],
                inheritance: inheritance,
                trustee: .everyone
            )
        ]
        if let secondaryPermission {
            entries.append(
                WindowsExplicitAccess(
                    permission: secondaryPermission,
                    inheritance: inheritance,
                    trustee: .users
                )
            )
        }
        return WindowsRawAcl(entries: .init(entries))
    }


    /// See `DaclCopyTests.makeParents`: different inheritable ACEs on the two parents
    /// are what makes copy and backup semantics distinguishable.
    private func makeParents(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> (srcParent: FilePath, dstParent: FilePath) {
        let srcParent = try workspace.makeDirectory(at: "src-parent")
        try Support.addWindowsDaclEntry(
            .init(
                permission: fileGenericReadAccessMask,
                inheritance: .allSubItems,
                trustee: .users
            ),
            at: srcParent,
            sourceLocation: sourceLocation
        )
        let dstParent = try workspace.makeDirectory(at: "dst-parent")
        try Support.addWindowsDaclEntry(
            .init(
                permission: fileGenericReadAccessMask,
                inheritance: .allSubItems,
                trustee: .authenticatedUsers
            ),
            at: dstParent,
            sourceLocation: sourceLocation
        )
        return (srcParent, dstParent)
    }


    @Test
    func `Preserves the exact SDDL of a protected source`() throws {

        let (_, dstParent) = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        try Support.setProtectedNativeWindowsDacl(
            makeSampleDacl(secondaryPermission: fileGenericReadAccessMask),
            at: src,
            followSymlink: true
        )
        let srcSddl = try Support.windowsSddlString(ofItemAt: src)
        let dst = dstParent.appending("dst.txt")

        try fileSystem.copyItem(at: src, to: dst, options: exactDaclOptions)

        #expect(try Support.windowsSddlString(ofItemAt: dst) == srcSddl)

    }


    @Test
    func `Preserves the exact SDDL of an auto-inherited source`() throws {

        let (_, dstParent) = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        try Support.addWindowsDaclEntry(
            .init(permission: fileGenericWriteAccessMask, trustee: .everyone),
            at: src
        )
        let srcSddl = try Support.windowsSddlString(ofItemAt: src)
        let dst = dstParent.appending("dst.txt")

        try fileSystem.copyItem(at: src, to: dst, options: exactDaclOptions)

        // Backup semantics: the destination carries the source's entries — including
        // the ones the source inherited from *its* parent — and nothing from the
        // destination parent is mixed in.
        #expect(try Support.windowsSddlString(ofItemAt: dst) == srcSddl)

    }


    /// Replaces the DACL with an everyone-full-access one so the workspace cleanup can
    /// remove the tree even when the test fails mid-way. The owner always has implicit
    /// WRITE_DAC, so this cannot fail; call from a `defer`.
    private func restoreDeletableDacl(at path: FilePath) {
        let dacl = WindowsRawAcl(entries: [
            .init(
                permission: .init(rawValue: DWORD(FILE_ALL_ACCESS)),
                inheritance: .allSubItems,
                trustee: .everyone
            )
        ])
        try? Support.setProtectedNativeWindowsDacl(dacl, at: path, followSymlink: false)
    }


    @Test
    func `Overwriting an existing destination preserves the exact DACL`() throws {

        _ = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        try Support.setProtectedNativeWindowsDacl(
            makeSampleDacl(secondaryPermission: fileGenericReadAccessMask),
            at: src,
            followSymlink: true
        )
        let srcSddl = try Support.windowsSddlString(ofItemAt: src)
        let dst = try workspace.makeFile(at: "dst-parent/dst.txt", contents: "old contents")
        try Support.setProtectedNativeWindowsDacl(
            makeSampleDacl(secondaryPermission: fileGenericWriteAccessMask),
            at: dst,
            followSymlink: true
        )

        try fileSystem.copyItem(at: src, to: dst, options: exactDaclOptions)

        // The temporary file is pre-created with a protected owner-only SD and its
        // content written through `CopyFileW(overwrite)`, which does not reset the SD.
        // This copy succeeding is also the sentinel for the default share mode
        // ([.read, .write, .delete]): the pre-created handle stays open across the
        // content write and the rename.
        #expect(try Support.windowsSddlString(ofItemAt: dst) == srcSddl)

    }


    @Test
    func `Overwrite merges into a restricted existing directory`() throws {

        _ = try makeParents()
        let src = try workspace.makeFixture(
            at: "src-parent/dir",
            [
                "file.txt": .file(contents: "src file")
            ]
        )
        let dst = try workspace.makeDirectory(at: "dst-parent/dir")
        defer {
            restoreDeletableDacl(at: src)
            restoreDeletableDacl(at: dst)
        }
        try Support.setProtectedNativeWindowsDacl(
            makeSampleDacl(inheritance: .allSubItems),
            at: src,
            followSymlink: false
        )
        let srcSddl = try Support.windowsSddlString(ofItemAt: src)
        // Only a read grant for the current user: without the temporary self-full-access
        // entry the copy could not create anything inside.
        let restrictiveDacl = WindowsRawAcl(entries: [
            .init(
                permission: fileGenericReadAccessMask,
                trustee: .init(sid: try Support.currentUserIdentity().rawId, type: .user)
            )
        ])
        try Support.setProtectedNativeWindowsDacl(restrictiveDacl, at: dst, followSymlink: false)

        try fileSystem.copyItem(
            at: src,
            to: dst,
            options: .init(
                existingTarget: .overwrite,
                windowsPreserveExactDacl: true
            )
        )

        // The temporary full-access entry made the content writable; the final commit
        // replaces it with the source's exact DACL.
        #expect(try Support.windowsSddlString(ofItemAt: dst) == srcSddl)
        try Support.expectItemExistNoFollow(at: dst.appending("file.txt"))

    }

}

#endif
