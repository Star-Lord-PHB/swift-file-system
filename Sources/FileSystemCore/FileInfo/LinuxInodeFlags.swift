#if canImport(Glibc) || canImport(Musl)

import PlatformCLib
import struct SystemPackage.FilePath


public struct LinuxInodeFlags: Sendable, OptionSet, Hashable {

    public let rawValue: PlatformInteropTypes.PosixInodeFlags

    @inlinable
    public init(rawValue: PlatformInteropTypes.PosixInodeFlags) {
        self.rawValue = rawValue
    }

}



extension LinuxInodeFlags {

    @inlinable public static var secureDeletion: Self { .init(rawValue: FS_SECRM_FL) }
    @inlinable public static var undelete: Self { .init(rawValue: FS_UNRM_FL) }
    @inlinable public static var compress: Self { .init(rawValue: FS_COMPR_FL) }
    @inlinable public static var synchronousUpdates: Self { .init(rawValue: FS_SYNC_FL) }
    @inlinable public static var immutable: Self { .init(rawValue: FS_IMMUTABLE_FL) }
    @inlinable public static var appendOnly: Self { .init(rawValue: FS_APPEND_FL) }
    @inlinable public static var noDump: Self { .init(rawValue: FS_NODUMP_FL) }
    @inlinable public static var noAtime: Self { .init(rawValue: FS_NOATIME_FL) }
    @inlinable public static var dirty: Self { .init(rawValue: FS_DIRTY_FL) }
    @inlinable public static var compressedClusters: Self { .init(rawValue: FS_COMPRBLK_FL) }
    @inlinable public static var noCompress: Self { .init(rawValue: FS_NOCOMP_FL) }
    @inlinable public static var encrypted: Self { .init(rawValue: FS_ENCRYPT_FL) }
    @available(*, deprecated, renamed: "indexedDirectory")
    @inlinable public static var btreeDirectory: Self { indexedDirectory }
    @inlinable public static var indexedDirectory: Self { .init(rawValue: FS_INDEX_FL) }
    @inlinable public static var afsDirectory: Self { .init(rawValue: FS_IMAGIC_FL) }
    @inlinable public static var journaledData: Self { .init(rawValue: FS_JOURNAL_DATA_FL) }
    @inlinable public static var noTail: Self { .init(rawValue: FS_NOTAIL_FL) }
    @inlinable public static var dirSync: Self { .init(rawValue: FS_DIRSYNC_FL) }
    @inlinable public static var topDirectory: Self { .init(rawValue: FS_TOPDIR_FL) }
    @inlinable public static var hugeFile: Self { .init(rawValue: FS_HUGE_FILE_FL) }
    @inlinable public static var extents: Self { .init(rawValue: FS_EXTENT_FL) }
    @inlinable public static var verityProtected: Self { .init(rawValue: FS_VERITY_FL) }
    @inlinable public static var eaInode: Self { .init(rawValue: FS_EA_INODE_FL) }
    @inlinable public static var eofBlocks: Self { .init(rawValue: FS_EOFBLOCKS_FL) }
    @inlinable public static var noCow: Self { .init(rawValue: FS_NOCOW_FL) }
    @inlinable public static var dax: Self { .init(rawValue: FS_DAX_FL) }
    @inlinable public static var inlineData: Self { .init(rawValue: FS_INLINE_DATA_FL) }
    @inlinable public static var projectInherit: Self { .init(rawValue: FS_PROJINHERIT_FL) }
    @inlinable public static var caseInsensitive: Self { .init(rawValue: FS_CASEFOLD_FL) }
    @inlinable public static var reservedForExt2: Self { .init(rawValue: .init(bitPattern: FS_RESERVED_FL)) }


    @inlinable public static var all: Self {[
        .secureDeletion, .undelete, .compress, .synchronousUpdates, .immutable, 
        .appendOnly, .noDump, .noAtime, .dirty, .compressedClusters, .noCompress, 
        .encrypted, .indexedDirectory, .afsDirectory, .journaledData, .noTail, 
        .dirSync, .topDirectory, .hugeFile, .extents, .verityProtected, .eaInode, 
        .eofBlocks, .noCow, .dax, .inlineData, .projectInherit, .caseInsensitive, 
        .reservedForExt2
    ]}


    static var allWithName: [(Self, StaticString)] {[
        (.secureDeletion, "secureDeletion"),
        (.undelete, "undelete"),
        (.compress, "compress"),
        (.synchronousUpdates, "synchronousUpdates"),
        (.immutable, "immutable"),
        (.appendOnly, "appendOnly"),
        (.noDump, "noDump"),
        (.noAtime, "noAtime"),
        (.dirty, "dirty"),
        (.compressedClusters, "compressedClusters"),
        (.noCompress, "noCompress"),
        (.encrypted, "encrypted"),
        (.indexedDirectory, "indexedDirectory"),
        (.afsDirectory, "afsDirectory"),
        (.journaledData, "journaledData"),
        (.noTail, "noTail"),
        (.dirSync, "dirSync"),
        (.topDirectory, "topDirectory"),
        (.hugeFile, "hugeFile"),
        (.extents, "extents"),
        (.verityProtected, "verityProtected"),
        (.eaInode, "eaInode"),
        (.eofBlocks, "eofBlocks"),
        (.noCow, "noCow"),
        (.dax, "dax"),
        (.inlineData, "inlineData"),
        (.projectInherit, "projectInherit"),
        (.caseInsensitive, "caseInsensitive"),
        (.reservedForExt2, "reservedForExt2")
    ]}

}



extension LinuxInodeFlags: CustomStringConvertible {

    public var description: String {
        let str = Self.allWithName
            .filter { flag, _ in self.contains(flag) }
            .map { _, name in name.description }
            .joined(separator: ", ")
        return "0x\(String(rawValue, radix: 16)) [\(str)]"
    }

}

#endif
