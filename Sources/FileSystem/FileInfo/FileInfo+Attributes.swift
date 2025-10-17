import Foundation
import SystemPackage
import CFileSystem

#if canImport(WinSDK)
import WinSDK
#endif


extension FileInfo {

    public struct PlatformAttributes: Sendable, OptionSet, Hashable {

    #if canImport(Glibc) || canImport(Musl)
        public typealias RawBitType = UInt64
    #elseif canImport(WinSDK)
        public typealias RawBitType = DWORD
    #else 
        public typealias RawBitType = UInt32
    #endif


        @_alwaysEmitIntoClient
        public private(set) var rawValue: RawBitType


        @inlinable
        public init(rawValue: RawBitType) {
            self.rawValue = rawValue
        }


        @inlinable
        public mutating func set(_ value: Bool, for attr: RawBitType) {
            if value {
                rawValue |= attr
            } else {
                rawValue &= ~attr
            }
        }

    }

}



extension FileInfo.PlatformAttributes {

    @inlinable
    public static func | (left: Self, right: Self) -> Self {
        .init(rawValue: left.rawValue | right.rawValue)
    }

}



#if canImport(Darwin)
extension FileInfo.Attributes {

    @inlinable public static var bitNoDump: RawBitType { .init(UF_NODUMP) }
    @inlinable public static var bitIsUserImmutable: RawBitType { .init(UF_IMMUTABLE) }
    @inlinable public static var bitIsUserAppendOnly: RawBitType { .init(UF_APPEND) }
    @inlinable public static var bitIsOpaque: RawBitType { .init(UF_OPAQUE) }
    @inlinable public static var bitIsCompressed: RawBitType { .init(UF_COMPRESSED) }
    @inlinable public static var bitIsHidden: RawBitType { .init(UF_HIDDEN) }
    @inlinable public static var bitIsArchived: RawBitType { .init(SF_ARCHIVED) }
    @inlinable public static var bitIsSystemImmutable: RawBitType { .init(SF_IMMUTABLE) }
    @inlinable public static var bitIsSystemAppendOnly: RawBitType { .init(SF_APPEND) }

    @inlinable public static var noDump: Self { .init(rawValue: bitNoDump) }
    @inlinable public static var isUserImmutable: Self { .init(rawValue: bitIsUserImmutable) }
    @inlinable public static var isUserAppendOnly: Self { .init(rawValue: bitIsUserAppendOnly) }
    @inlinable public static var isOpaque: Self { .init(rawValue: bitIsOpaque) }
    @inlinable public static var isCompressed: Self { .init(rawValue: bitIsCompressed) }
    @inlinable public static var isHidden: Self { .init(rawValue: bitIsHidden) }
    @inlinable public static var isArchived: Self { .init(rawValue: bitIsArchived) }
    @inlinable public static var isSystemImmutable: Self { .init(rawValue: bitIsSystemImmutable) }
    @inlinable public static var isSystemAppendOnly: Self { .init(rawValue: bitIsSystemAppendOnly) }

    @usableFromInline static let _all: Self = [
        .noDump, .isUserImmutable, .isUserAppendOnly, .isOpaque, .isCompressed, .isHidden, .isArchived,
        .isSystemImmutable, .isSystemAppendOnly
    ]
    @inlinable public static var all: Self { _all }

    @inlinable 
    public var noDump: Bool {
        get { (rawValue & Self.bitNoDump) != 0 }
        set { set(newValue, for: Self.bitNoDump) }
    }

    @inlinable 
    public var isUserImmutable: Bool {
        get { (rawValue & Self.bitIsUserImmutable) != 0 }
        set { set(newValue, for: Self.bitIsUserImmutable) }
    }

    @inlinable
    public var isUserAppendOnly: Bool {
        get { (rawValue & Self.bitIsUserAppendOnly) != 0 }
        set { set(newValue, for: Self.bitIsUserAppendOnly) }
    }

    @inlinable
    public var isOpaque: Bool {
        get { (rawValue & Self.bitIsOpaque) != 0 }
        set { set(newValue, for: Self.bitIsOpaque) }
    }

    @inlinable
    public var isCompressed: Bool {
        get { (rawValue & Self.bitIsCompressed != 0) }
        set { set(newValue, for: Self.bitIsCompressed) }
    }

    @inlinable
    public var isHidden: Bool {
        get { (rawValue & Self.bitIsHidden) != 0 }
        set { set(newValue, for: Self.bitIsHidden) }
    }

    @inlinable
    public var isArchived: Bool {
        get { (rawValue & Self.bitIsArchived) != 0 }
        set { set(newValue, for: Self.bitIsArchived) }
    }

    @inlinable
    public var isSystemImmutable: Bool {
        get { (rawValue & Self.bitIsSystemImmutable) != 0 }
        set { set(newValue, for: Self.bitIsSystemImmutable) }
    }

    @inlinable
    public var isSystemAppendOnly: Bool {
        get { (rawValue & Self.bitIsSystemAppendOnly) != 0 }
        set { set(newValue, for: Self.bitIsSystemAppendOnly) }
    }

}
#endif



#if canImport(Glibc) || canImport(Musl)
extension FileInfo.Attributes {

    @inlinable public static var bitIsCompressed: RawBitType { .init(STATX_ATTR_COMPRESSED) }
    @inlinable public static var bitIsImmutable: RawBitType { .init(STATX_ATTR_IMMUTABLE) }
    @inlinable public static var bitIsAppendOnly: RawBitType { .init(STATX_ATTR_APPEND) }
    @inlinable public static var bitNoDump: RawBitType { .init(STATX_ATTR_NODUMP) }
    @inlinable public static var bitIsEncrypted: RawBitType { .init(STATX_ATTR_ENCRYPTED) }
    @inlinable public static var bitIsAutoMount: RawBitType { .init(STATX_ATTR_AUTOMOUNT) }
    @inlinable public static var bitIsMountRoot: RawBitType { .init(STATX_ATTR_MOUNT_ROOT) }
    @inlinable public static var bitIsVerityProtected: RawBitType { .init(STATX_ATTR_VERITY) }
    @inlinable public static var bitIsDAX: RawBitType { .init(STATX_ATTR_DAX) }

    @inlinable public static var systemSupportAttrIsCompressed: Bool { HAS_STATX_ATTR_COMPRESSED }
    @inlinable public static var systemSupportAttrIsImmutable: Bool { HAS_STATX_ATTR_IMMUTABLE }
    @inlinable public static var systemSupportAttrIsAppendOnly: Bool { HAS_STATX_ATTR_APPEND }
    @inlinable public static var systemSupportAttrNoDump: Bool { HAS_STATX_ATTR_NODUMP }
    @inlinable public static var systemSupportAttrIsEncrypted: Bool { HAS_STATX_ATTR_ENCRYPTED }
    @inlinable public static var systemSupportAttrIsAutoMount: Bool { HAS_STATX_ATTR_AUTOMOUNT }
    @inlinable public static var systemSupportAttrIsMountRoot: Bool { HAS_STATX_ATTR_MOUNT_ROOT }
    @inlinable public static var systemSupportAttrIsVerityProtected: Bool { HAS_STATX_ATTR_VERITY }
    @inlinable public static var systemSupportAttrIsDAX: Bool { HAS_STATX_ATTR_DAX }

    @inlinable public static var isCompressed: Self { .init(rawValue: bitIsCompressed) }
    @inlinable public static var isImmutable: Self { .init(rawValue: bitIsImmutable) }
    @inlinable public static var isAppendOnly: Self { .init(rawValue: bitIsAppendOnly) }
    @inlinable public static var noDump: Self { .init(rawValue: bitNoDump) }
    @inlinable public static var isEncrypted: Self { .init(rawValue: bitIsEncrypted) }
    @inlinable public static var isAutoMount: Self { .init(rawValue: bitIsAutoMount) }
    @inlinable public static var isMountRoot: Self { .init(rawValue: bitIsMountRoot) }
    @inlinable public static var isVerityProtected: Self { .init(rawValue: bitIsVerityProtected) }
    @inlinable public static var isDAX: Self { .init(rawValue: bitIsDAX) }

    @usableFromInline static let _all: Self = [
        .isCompressed, .isImmutable, .isAppendOnly, .noDump, .isEncrypted,
        .isAutoMount, .isMountRoot, .isVerityProtected, .isDAX
    ]
    @inlinable public static var all: Self { _all }

    @inlinable
    public var isCompressed: Bool {
        get { Self.systemSupportAttrIsCompressed && (rawValue & Self.bitIsCompressed) != 0 }
        set { set(newValue, for: Self.bitIsCompressed) }
    }

    @inlinable
    public var isImmutable: Bool {
        get { Self.systemSupportAttrIsImmutable && (rawValue & Self.bitIsImmutable) != 0 }
        set { set(newValue, for: Self.bitIsImmutable) }
    }

    @inlinable
    public var isAppendOnly: Bool {
        get { Self.systemSupportAttrIsAppendOnly && (rawValue & Self.bitIsAppendOnly) != 0 }
        set { set(newValue, for: Self.bitIsAppendOnly) }
    }

    @inlinable
    public var noDump: Bool {
        get { Self.systemSupportAttrNoDump && (rawValue & Self.bitNoDump) != 0 }
        set { set(newValue, for: Self.bitNoDump) }
    }

    @inlinable
    public var isEncrypted: Bool {
        get { Self.systemSupportAttrIsEncrypted && (rawValue & Self.bitIsEncrypted) != 0 }
        set { set(newValue, for: Self.bitIsEncrypted) }
    }

    @inlinable
    public var isAutoMount: Bool {
        get { Self.systemSupportAttrIsAutoMount && (rawValue & Self.bitIsAutoMount) != 0 }
        set { set(newValue, for: Self.bitIsAutoMount) }
    }

    @inlinable
    public var isMountRoot: Bool {
        get { Self.systemSupportAttrIsMountRoot && (rawValue & Self.bitIsMountRoot) != 0 }
        set { set(newValue, for: Self.bitIsMountRoot) }
    }

    @inlinable
    public var isVerityProtected: Bool {
        get { Self.systemSupportAttrIsVerityProtected && (rawValue & Self.bitIsVerityProtected) != 0 }
        set { set(newValue, for: Self.bitIsVerityProtected) }
    }

    @inlinable
    public var isDAX: Bool {
        get { Self.systemSupportAttrIsDAX && (rawValue & Self.bitIsDAX) != 0 }
        set { set(newValue, for: Self.bitIsDAX) }
    }

}
#endif



#if canImport(WinSDK)
extension FileInfo.PlatformAttributes {

    @inlinable public static var bitIsReadOnly: RawBitType { .init(FILE_ATTRIBUTE_READONLY) }
    @inlinable public static var bitIsHidden: RawBitType { .init(FILE_ATTRIBUTE_HIDDEN) }
    @inlinable public static var bitIsSystem: RawBitType { .init(FILE_ATTRIBUTE_SYSTEM) }
    @inlinable public static var bitIsDirectory: RawBitType { .init(FILE_ATTRIBUTE_DIRECTORY) }
    @inlinable public static var bitIsArchive: RawBitType { .init(FILE_ATTRIBUTE_ARCHIVE) }
    @inlinable public static var bitIsDevice: RawBitType { .init(FILE_ATTRIBUTE_DEVICE) }
    @inlinable public static var bitIsNormal: RawBitType { .init(FILE_ATTRIBUTE_NORMAL) }
    @inlinable public static var bitIsTemporary: RawBitType { .init(FILE_ATTRIBUTE_TEMPORARY) }
    @inlinable public static var bitIsSparseFile: RawBitType { .init(FILE_ATTRIBUTE_SPARSE_FILE) }
    @inlinable public static var bitIsReparsePoint: RawBitType { .init(FILE_ATTRIBUTE_REPARSE_POINT) }
    @inlinable public static var bitIsCompressed: RawBitType { .init(FILE_ATTRIBUTE_COMPRESSED) }
    @inlinable public static var bitIsOffline: RawBitType { .init(FILE_ATTRIBUTE_OFFLINE) }
    @inlinable public static var bitIsNotContentIndexed: RawBitType { .init(FILE_ATTRIBUTE_NOT_CONTENT_INDEXED) }
    @inlinable public static var bitIsEncrypted: RawBitType { .init(FILE_ATTRIBUTE_ENCRYPTED) }
    @inlinable public static var bitIsIntegrityStream: RawBitType { .init(FILE_ATTRIBUTE_INTEGRITY_STREAM) }
    @inlinable public static var bitIsVirtual: RawBitType { .init(FILE_ATTRIBUTE_VIRTUAL) }
    @inlinable public static var bitIsNoScrubData: RawBitType { .init(FILE_ATTRIBUTE_NO_SCRUB_DATA) }
    @inlinable public static var bitsIsPinned: RawBitType { .init(FILE_ATTRIBUTE_PINNED) }
    @inlinable public static var bitsIsUnpinned: RawBitType { .init(FILE_ATTRIBUTE_UNPINNED) }
    @inlinable public static var bitsRecallOnOpen: RawBitType { .init(FILE_ATTRIBUTE_RECALL_ON_OPEN) }
    @inlinable public static var bitsRecallOnDataAccess: RawBitType { .init(FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS) }

    @inlinable public static var isReadOnly: Self { .init(rawValue: bitIsReadOnly) }
    @inlinable public static var isHidden: Self { .init(rawValue: bitIsHidden) }
    @inlinable public static var isSystem: Self { .init(rawValue: bitIsSystem) }
    @inlinable public static var isDirectory: Self { .init(rawValue: bitIsDirectory) }
    @inlinable public static var isArchive: Self { .init(rawValue: bitIsArchive) }
    @inlinable public static var isDevice: Self { .init(rawValue: bitIsDevice) }
    @inlinable public static var isNormal: Self { .init(rawValue: bitIsNormal) }
    @inlinable public static var isTemporary: Self { .init(rawValue: bitIsTemporary) }
    @inlinable public static var isSparseFile: Self { .init(rawValue: bitIsSparseFile) }
    @inlinable public static var isReparsePoint: Self { .init(rawValue: bitIsReparsePoint) }
    @inlinable public static var isCompressed: Self { .init(rawValue: bitIsCompressed) }
    @inlinable public static var isOffline: Self { .init(rawValue: bitIsOffline) }
    @inlinable public static var isNotContentIndexed: Self { .init(rawValue: bitIsNotContentIndexed) }
    @inlinable public static var isEncrypted: Self { .init(rawValue: bitIsEncrypted) }
    @inlinable public static var isIntegrityStream: Self { .init(rawValue: bitIsIntegrityStream) }
    @inlinable public static var isVirtual: Self { .init(rawValue: bitIsVirtual) }
    @inlinable public static var isNoScrubData: Self { .init(rawValue: bitIsNoScrubData) }
    @inlinable public static var isPinned: Self { .init(rawValue: bitsIsPinned) }
    @inlinable public static var isUnpinned: Self { .init(rawValue: bitsIsUnpinned) }
    @inlinable public static var recallOnOpen: Self { .init(rawValue: bitsRecallOnOpen) }
    @inlinable public static var recallOnDataAccess: Self { .init(rawValue: bitsRecallOnDataAccess) }

    @usableFromInline static let _all: Self = [
        .isReadOnly, .isHidden, .isSystem, .isDirectory, .isArchive, .isDevice, .isNormal,
        .isTemporary, .isSparseFile, .isReparsePoint, .isCompressed, .isOffline,
        .isNotContentIndexed, .isEncrypted, .isIntegrityStream, .isVirtual, .isNoScrubData,
        .isPinned, .isUnpinned, .recallOnOpen, .recallOnDataAccess
    ]
    @inlinable public static var all: Self { _all }


    @inlinable
    public var isReadOnly: Bool {
        get { (rawValue & Self.bitIsReadOnly) != 0 }
        set { set(newValue, for: Self.bitIsReadOnly) }
    }

    @inlinable
    public var isHidden: Bool {
        get { (rawValue & Self.bitIsHidden) != 0 }
        set { set(newValue, for: Self.bitIsHidden) }
    }

    @inlinable
    public var isSystem: Bool {
        get { (rawValue & Self.bitIsSystem) != 0 }
        set { set(newValue, for: Self.bitIsSystem) }
    }

    @inlinable
    public var isDirectory: Bool {
        get { (rawValue & Self.bitIsDirectory) != 0 }
        set { set(newValue, for: Self.bitIsDirectory) }
    }

    @inlinable
    public var isArchive: Bool {
        get { (rawValue & Self.bitIsArchive) != 0 }
        set { set(newValue, for: Self.bitIsArchive) }
    }

    @inlinable
    public var isDevice: Bool {
        get { (rawValue & Self.bitIsDevice) != 0 }
        set { set(newValue, for: Self.bitIsDevice) }
    }

    @inlinable
    public var isNormal: Bool {
        get { (rawValue & Self.bitIsNormal) != 0 }
        set { set(newValue, for: Self.bitIsNormal) }
    }

    @inlinable
    public var isTemporary: Bool {
        get { (rawValue & Self.bitIsTemporary) != 0 }
        set { set(newValue, for: Self.bitIsTemporary) }
    }

    @inlinable
    public var isSparseFile: Bool {
        get { (rawValue & Self.bitIsSparseFile) != 0 }
        set { set(newValue, for: Self.bitIsSparseFile) }
    }

    @inlinable
    public var isReparsePoint: Bool {
        get { (rawValue & Self.bitIsReparsePoint) != 0 }
        set { set(newValue, for: Self.bitIsReparsePoint) }
    }

    @inlinable
    public var isCompressed: Bool {
        get { (rawValue & Self.bitIsCompressed) != 0 }
        set { set(newValue, for: Self.bitIsCompressed) }
    }

    @inlinable
    public var isOffline: Bool {
        get { (rawValue & Self.bitIsOffline) != 0 }
        set { set(newValue, for: Self.bitIsOffline) }
    }

    @inlinable
    public var isNotContentIndexed: Bool {
        get { (rawValue & Self.bitIsNotContentIndexed) != 0 }
        set { set(newValue, for: Self.bitIsNotContentIndexed) }
    }

    @inlinable
    public var isEncrypted: Bool {
        get { (rawValue & Self.bitIsEncrypted) != 0 }
        set { set(newValue, for: Self.bitIsEncrypted) }
    }

    @inlinable
    public var isIntegrityStream: Bool {
        get { (rawValue & Self.bitIsIntegrityStream) != 0 }
        set { set(newValue, for: Self.bitIsIntegrityStream) }
    }

    @inlinable
    public var isVirtual: Bool {
        get { (rawValue & Self.bitIsVirtual) != 0 }
        set { set(newValue, for: Self.bitIsVirtual) }
    }

    @inlinable
    public var isNoScrubData: Bool {
        get { (rawValue & Self.bitIsNoScrubData) != 0 }
        set { set(newValue, for: Self.bitIsNoScrubData) }
    }

    @inlinable
    public var isPinned: Bool {
        get { (rawValue & Self.bitsIsPinned) != 0 }
        set { set(newValue, for: Self.bitsIsPinned) }
    }

    @inlinable
    public var isUnpinned: Bool {
        get { (rawValue & Self.bitsIsUnpinned) != 0 }
        set { set(newValue, for: Self.bitsIsUnpinned) }
    }

    @inlinable
    public var recallOnOpen: Bool {
        get { (rawValue & Self.bitsRecallOnOpen) != 0 }
        set { set(newValue, for: Self.bitsRecallOnOpen) }
    }

    @inlinable
    public var recallOnDataAccess: Bool {
        get { (rawValue & Self.bitsRecallOnDataAccess) != 0 }
        set { set(newValue, for: Self.bitsRecallOnDataAccess) }
    }

}
#endif