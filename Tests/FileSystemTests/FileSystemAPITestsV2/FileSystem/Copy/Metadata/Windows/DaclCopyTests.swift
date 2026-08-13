#if canImport(WinSDK)

import Foundation
import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Windows DACL copy")
    struct DaclCopyTests {

        typealias Support = FileSystemAPITests.Support
        typealias Times = FileSystemTestSupport.ItemMetadata.Times

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: `SE_DACL_DEFAULTED` does not survive an NTFS write and is never asserted here.
extension FileSystemAPITests.CopyTests.DaclCopyTests {

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


    /// Creates the source and destination parent directories with *different*
    /// inheritable ACEs. With identical parents the copy and backup semantics produce
    /// identical results and the DACL tests would not test anything.
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


    private func captureSecurity(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Support.ItemMetadata.Security {
        try Support.ItemMetadata.captureSecurity(at: path, sourceLocation: sourceLocation)
    }


    private func isInherited(_ ace: Support.WindowsAceSnapshot) -> Bool {
        ace.flags & BYTE(INHERITED_ACE) != 0
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
    func `Pure inherited source DACL is not copied`() throws {

        let (_, dstParent) = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        let dst = dstParent.appending("dst.txt")
        // A fresh item is auto-inherited with every ACE marked INHERITED_ACE (surveyed:
        // this holds for CreateFileW, fopen, Foundation, cmd, and PowerShell creation
        // alike), so the copy finds no explicit entry and writes no DACL at all. The
        // probe is the oracle for what natural creation in the destination parent
        // inherits.
        let probe = try workspace.makeFile(at: "dst-parent/probe.txt", contents: "probe")
        let expectedDacl = try captureSecurity(at: probe).permissions.dacl

        try fileSystem.copyItem(at: src, to: dst)

        let dstPermissions = try captureSecurity(at: dst).permissions
        Support.expectWindowsAcl(dstPermissions.dacl, matches: expectedDacl)
        #expect(!dstPermissions.isProtected)
        #expect(try dstPermissions.dacl != captureSecurity(at: src).permissions.dacl)

    }


    /// Creates a directory whose SD lacks `SE_DACL_AUTO_INHERITED`: a non-propagating
    /// DACL write with a plain input SD clears the bit (and the kernel marks such a
    /// write protected). Files created inside come out in legacy mode, which no
    /// ordinary creation path produces — fresh items are always auto-inherited with
    /// marked ACEs, regardless of how they are created.
    private func makeLegacyModeDirectory(
        at relativePath: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> FilePath {
        let directory = try workspace.makeDirectory(at: relativePath)
        let dacl = makeSampleDacl(inheritance: .allSubItems)
        try dacl.withUnsafePACL { daclPointer in
            var descriptor = SECURITY_DESCRIPTOR()
            try #require(
                InitializeSecurityDescriptor(&descriptor, DWORD(SECURITY_DESCRIPTOR_REVISION)),
                sourceLocation: sourceLocation
            )
            try #require(
                SetSecurityDescriptorDacl(&descriptor, true, daclPointer, false),
                sourceLocation: sourceLocation
            )
            let written = directory.withPlatformString {
                SetFileSecurityW($0, DWORD(DACL_SECURITY_INFORMATION), &descriptor)
            }
            try #require(written, sourceLocation: sourceLocation)
        }
        return directory
    }


    @Test
    func `Legacy source with only marked entries is not copied`() throws {

        let (_, dstParent) = try makeParents()
        let legacyParent = try makeLegacyModeDirectory(at: "legacy-parent")
        // The inherited everyone-RWX entries carry no DELETE right and the parent grants
        // no FILE_DELETE_CHILD; restore a deletable DACL so the cleanup can proceed.
        defer { restoreDeletableDacl(at: legacyParent) }
        let src = try workspace.makeFile(at: "legacy-parent/file.txt", contents: "contents")
        let srcPermissions = try captureSecurity(at: src).permissions
        try #require(!srcPermissions.isAutoInherited)
        try #require(!srcPermissions.isProtected)
        try #require(srcPermissions.dacl.aces.allSatisfy { isInherited($0) })
        let dst = dstParent.appending("dst.txt")
        let probe = try workspace.makeFile(at: "dst-parent/probe.txt", contents: "probe")
        let expectedDacl = try captureSecurity(at: probe).permissions.dacl

        try fileSystem.copyItem(at: src, to: dst)

        // The INHERITED_ACE marks are kernel-stamped even without SE_DACL_AUTO_INHERITED,
        // so a legacy-mode item created naturally has no deliberately set entry and the
        // copy writes no DACL at all.
        let dstPermissions = try captureSecurity(at: dst).permissions
        Support.expectWindowsAcl(dstPermissions.dacl, matches: expectedDacl)

    }


    /// Rewrites the item's security descriptor through a plain non-propagating
    /// round-trip (read, then write back without the auto-inherit request bit), which
    /// clears `SE_DACL_AUTO_INHERITED` while keeping every entry and its marks — the
    /// mixed legacy shape old backup/copy tools leave behind.
    ///
    /// NOTE (surveyed): a DACL write whose entries are all unmarked gets implicitly
    /// marked protected by the kernel, whatever the input control or a requested
    /// `UNPROTECTED_DACL_SECURITY_INFORMATION` say. A "no protected bit, no
    /// auto-inherited bit, only unmarked entries" SD is therefore not constructible
    /// through the security APIs at all (only BackupWrite-level restores could produce
    /// one); wholesale-written self-contained DACLs come out protected and take the
    /// verbatim branch of the copy instead.
    private func stripDaclAutoInheritedBit(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let handle = path.withPlatformString {
            CreateFileW(
                $0, DWORD(READ_CONTROL) | DWORD(WRITE_DAC),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), nil,
                DWORD(OPEN_EXISTING), DWORD(FILE_FLAG_BACKUP_SEMANTICS), nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }

        var lengthNeeded = DWORD(0)
        GetKernelObjectSecurity(handle, DWORD(DACL_SECURITY_INFORMATION), nil, 0, &lengthNeeded)
        try #require(lengthNeeded > 0, sourceLocation: sourceLocation)
        var buffer = [UInt8](repeating: 0, count: Int(lengthNeeded))
        try buffer.withUnsafeMutableBytes { rawBuffer in
            try #require(
                GetKernelObjectSecurity(
                    handle,
                    DWORD(DACL_SECURITY_INFORMATION),
                    rawBuffer.baseAddress,
                    lengthNeeded,
                    &lengthNeeded
                ),
                sourceLocation: sourceLocation
            )
            try #require(
                SetKernelObjectSecurity(
                    handle,
                    DWORD(DACL_SECURITY_INFORMATION),
                    rawBuffer.baseAddress
                ),
                sourceLocation: sourceLocation
            )
        }
    }


    @Test
    func `Legacy source's unmarked entries are copied as explicit entries`() throws {

        // The mixed legacy shape: marked inherited entries plus an unmarked explicit
        // one, with no auto-inherited bit. The marks are trustworthy even without the
        // bit (the kernel stamps them at creation), so the explicit entry travels and
        // the marked ones stay behind — the old dispatch dropped all of them.
        let (_, dstParent) = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        try Support.addWindowsDaclEntry(
            .init(permission: fileGenericWriteAccessMask, trustee: .everyone),
            at: src
        )
        try stripDaclAutoInheritedBit(at: src)
        let srcPermissions = try captureSecurity(at: src).permissions
        try #require(!srcPermissions.isAutoInherited)
        try #require(!srcPermissions.isProtected)
        let srcExplicitAces = srcPermissions.dacl.aces.filter { !isInherited($0) }
        try #require(!srcExplicitAces.isEmpty)
        try #require(srcPermissions.dacl.aces.contains { isInherited($0) })
        let dst = dstParent.appending("dst.txt")
        let probe = try workspace.makeFile(at: "dst-parent/probe.txt", contents: "probe")
        let probeInheritedAces = try captureSecurity(at: probe).permissions.dacl.aces
            .filter { isInherited($0) }

        try fileSystem.copyItem(at: src, to: dst)

        let dstPermissions = try captureSecurity(at: dst).permissions
        let dstAces = dstPermissions.dacl.aces
        #expect(dstAces.filter { !isInherited($0) } == srcExplicitAces)
        #expect(dstAces.filter { isInherited($0) } == probeInheritedAces)
        #expect(dstPermissions.isAutoInherited)

    }


    @Test
    func `Auto-inherited source merges explicit entries ahead of inheritance`() throws {

        let (_, dstParent) = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        // A fresh file is already auto-inherited; the propagating edit adds the
        // explicit entry in canonical position.
        try Support.addWindowsDaclEntry(
            .init(permission: fileGenericWriteAccessMask, trustee: .everyone),
            at: src
        )
        let srcPermissions = try captureSecurity(at: src).permissions
        try #require(srcPermissions.isAutoInherited)
        let srcExplicitAces = srcPermissions.dacl.aces.filter { !isInherited($0) }
        try #require(!srcExplicitAces.isEmpty)
        let dst = dstParent.appending("dst.txt")
        let probe = try workspace.makeFile(at: "dst-parent/probe.txt", contents: "probe")
        let probeInheritedAces = try captureSecurity(at: probe).permissions.dacl.aces
            .filter { isInherited($0) }

        try fileSystem.copyItem(at: src, to: dst)

        // Canonical result: the source's explicit entries in front (unmarked), then
        // exactly the inherited entries natural creation in the destination parent
        // produces. The merged SD is stamped auto-inherited, so copying the copy keeps
        // its explicit entries too (see the dedicated test below).
        let dstPermissions = try captureSecurity(at: dst).permissions
        let dstAces = dstPermissions.dacl.aces
        let dstExplicitAces = dstAces.filter { !isInherited($0) }
        let dstInheritedAces = dstAces.filter { isInherited($0) }
        #expect(dstExplicitAces == srcExplicitAces)
        #expect(dstInheritedAces == probeInheritedAces)
        #expect(dstAces == dstExplicitAces + dstInheritedAces)
        #expect(dstPermissions.isAutoInherited)
        #expect(!dstPermissions.isProtected)

    }


    @Test
    func `Copy of a merged copy keeps the explicit entries`() throws {

        // Pins the copy chain staying stable: the merged destination keeps its explicit
        // entries unmarked (and its SD stamped auto-inherited), so copying the copy
        // carries them again.
        let (_, dstParent) = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        try Support.addWindowsDaclEntry(
            .init(permission: fileGenericWriteAccessMask, trustee: .everyone),
            at: src
        )
        let srcExplicitAces = try captureSecurity(at: src).permissions.dacl.aces
            .filter { !isInherited($0) }
        try #require(!srcExplicitAces.isEmpty)
        let firstDst = dstParent.appending("first.txt")
        let secondDst = dstParent.appending("second.txt")

        try fileSystem.copyItem(at: src, to: firstDst)
        try fileSystem.copyItem(at: firstDst, to: secondDst)

        let secondExplicitAces = try captureSecurity(at: secondDst).permissions.dacl.aces
            .filter { !isInherited($0) }
        #expect(secondExplicitAces == srcExplicitAces)

    }


    @Test
    func `Protected source DACL is written verbatim`() throws {

        let (_, dstParent) = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        let protectedDacl = makeSampleDacl(secondaryPermission: fileGenericReadAccessMask)
        let expectedDacl = try Support.parseWindowsRawAcl(protectedDacl)
        try Support.setProtectedNativeWindowsDacl(protectedDacl, at: src, followSymlink: true)
        let dst = dstParent.appending("dst.txt")

        try fileSystem.copyItem(at: src, to: dst)

        // The protected bit blocks inheritance, so nothing from the destination parent
        // appears. The source was installed through a propagating API and is therefore
        // also auto-inherited; the bookkeeping bit travels with the verbatim write.
        let dstPermissions = try captureSecurity(at: dst).permissions
        #expect(dstPermissions.isProtected)
        #expect(dstPermissions.isAutoInherited)
        Support.expectWindowsAcl(dstPermissions.dacl, matches: expectedDacl)

    }


    @Test
    func `Protected null DACL copies as everyone-full-access`() throws {

        let (_, dstParent) = try makeParents()
        let src = try workspace.makeFile(at: "src-parent/file.txt", contents: "contents")
        try Support.applyWindowsNullProtectedDacl(at: src)
        let dst = dstParent.appending("dst.txt")

        try fileSystem.copyItem(at: src, to: dst)

        // A NULL DACL means everyone has full access; copying it faithfully is the
        // deliberate behavior.
        let dstPermissions = try captureSecurity(at: dst).permissions
        #expect(dstPermissions.isProtected)
        #expect(dstPermissions.dacl.state == .null)
        #expect(dstPermissions.dacl.aces.isEmpty)

    }


    @Test
    func `Overwrite merge does not touch existing children's DACLs`() throws {

        _ = try makeParents()
        let src = try workspace.makeDirectory(at: "src-parent/dir")
        try workspace.makeFile(at: "src-parent/dir/new.txt", contents: "src new")
        try Support.addWindowsDaclEntry(
            .init(permission: fileGenericWriteAccessMask, trustee: .everyone),
            at: src
        )
        let srcExplicitAces = try captureSecurity(at: src).permissions.dacl.aces
            .filter { !isInherited($0) }
        try #require(!srcExplicitAces.isEmpty)
        let dst = try workspace.makeDirectory(at: "dst-parent/dir")
        let keep = try workspace.makeFile(at: "dst-parent/dir/keep.txt", contents: "keep")
        let keepSecurityBefore = try captureSecurity(at: keep)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        // The merged directory itself received the source's explicit entries...
        let dstExplicitAces = try captureSecurity(at: dst).permissions.dacl.aces
            .filter { !isInherited($0) }
        #expect(dstExplicitAces == srcExplicitAces)
        // ...but the write is non-propagating: the pre-existing child keeps its old
        // security untouched.
        Support.expectWindowsSecurity(try captureSecurity(at: keep), matches: keepSecurityBefore)

    }


    @Test
    func `DACL write does not push the destination access time`() throws {

        if try !Support.volumeUpdatesAccessTimeOnRead(in: workspace) {
            try Test.cancel("The volume does not update access times on read")
        }

        // A protected source guarantees the destination commit writes a DACL, and the
        // DACL is written last — after the times. A propagating ACL API would push the
        // access time here; the non-propagating writes the copy uses do not.
        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "contents")
            ]
        )
        let dst = workspace.path("dst")
        defer {
            restoreDeletableDacl(at: src)
            restoreDeletableDacl(at: dst)
        }
        try Support.setProtectedNativeWindowsDacl(
            makeSampleDacl(inheritance: .allSubItems),
            at: src,
            followSymlink: false
        )
        try Support.ageAccessTime(at: src)
        let srcBefore = try Times.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        let dstTimes = try Times.capture(at: dst)
        #expect(dstTimes.access == srcBefore.access)

    }

}

#endif
