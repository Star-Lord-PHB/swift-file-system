#if canImport(Glibc) || canImport(Musl)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileInfoAPITests.PlatformFileAttributeTests {

    @Suite("Linux inode flags")
    struct LinuxInodeFlagTests {}

}



extension FileInfoAPITests.PlatformFileAttributeTests.LinuxInodeFlagTests {

    @Test(
        arguments: [
            (.secureDeletion, FS_SECRM_FL),
            (.undelete, FS_UNRM_FL),
            (.compress, FS_COMPR_FL),
            (.synchronousUpdates, FS_SYNC_FL),
            (.immutable, FS_IMMUTABLE_FL),
            (.appendOnly, FS_APPEND_FL),
            (.noDump, FS_NODUMP_FL),
            (.noAtime, FS_NOATIME_FL),
            (.dirty, FS_DIRTY_FL),
            (.compressedClusters, FS_COMPRBLK_FL),
            (.noCompress, FS_NOCOMP_FL),
            (.encrypted, FS_ENCRYPT_FL),
            (.indexedDirectory, FS_INDEX_FL),
            (.afsDirectory, FS_IMAGIC_FL),
            (.journaledData, FS_JOURNAL_DATA_FL),
            (.noTail, FS_NOTAIL_FL),
            (.dirSync, FS_DIRSYNC_FL),
            (.topDirectory, FS_TOPDIR_FL),
            (.hugeFile, FS_HUGE_FILE_FL),
            (.extents, FS_EXTENT_FL),
            (.verityProtected, FS_VERITY_FL),
            (.eaInode, FS_EA_INODE_FL),
            (.eofBlocks, FS_EOFBLOCKS_FL),
            (.noCow, FS_NOCOW_FL),
            (.dax, FS_DAX_FL),
            (.inlineData, FS_INLINE_DATA_FL),
            (.projectInherit, FS_PROJINHERIT_FL),
            (.caseInsensitive, FS_CASEFOLD_FL),
            (.reservedForExt2, .init(bitPattern: FS_RESERVED_FL))
        ] as [(LinuxInodeFlags, PlatformInteropTypes.PosixInodeFlags)]
    )
    func `Inode flags map to native flags`(
        _ flag: LinuxInodeFlags,
        _ rawValue: PlatformInteropTypes.PosixInodeFlags
    ) {

        #expect(flag.rawValue == rawValue)

    }


    @Test
    func `All contains every inode flag`() {

        let expected: LinuxInodeFlags = [
            .secureDeletion, .undelete, .compress, .synchronousUpdates,
            .immutable, .appendOnly, .noDump, .noAtime, .dirty,
            .compressedClusters, .noCompress, .encrypted, .indexedDirectory,
            .afsDirectory, .journaledData, .noTail, .dirSync, .topDirectory,
            .hugeFile, .extents, .verityProtected, .eaInode, .eofBlocks,
            .noCow, .dax, .inlineData, .projectInherit, .caseInsensitive,
            .reservedForExt2
        ]

        #expect(LinuxInodeFlags.all == expected)

    }

}

#endif
