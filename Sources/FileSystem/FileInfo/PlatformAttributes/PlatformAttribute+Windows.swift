#if canImport(WinSDK)

import WinSDK


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

    @usableFromInline
    static var _allWithNameAsArray: [(Self, StaticString)]? {
        [
            (.isReadOnly, "isReadOnly"), (.isHidden, "isHidden"), (.isSystem, "isSystem"), (.isDirectory, "isDirectory"), 
            (.isArchive, "isArchive"), (.isDevice, "isDevice"), (.isNormal, "isNormal"), (.isTemporary, "isTemporary"),
            (.isSparseFile, "isSparseFile"), (.isReparsePoint, "isReparsePoint"), (.isCompressed, "isCompressed"),
            (.isOffline, "isOffline"), (.isNotContentIndexed, "isNotContentIndexed"), (.isEncrypted, "isEncrypted"),
            (.isIntegrityStream, "isIntegrityStream"), (.isVirtual, "isVirtual"), (.isNoScrubData, "isNoScrubData"),
            (.isPinned, "isPinned"), (.isUnpinned, "isUnpinned"), (.recallOnOpen, "recallOnOpen"), (.recallOnDataAccess, "recallOnDataAccess")
        ]
    }
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