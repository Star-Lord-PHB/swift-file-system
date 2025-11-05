#if canImport(Glibc) || canImport(Musl)

import PlatformCLib
import CFileSystem


extension FileInfo.PlatformAttributes {

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

    @usableFromInline
    static var _allWithNameAsArray: [(Self, StaticString)]? {
        [
            (.isCompressed, "isCompressed"), (.isImmutable, "isImmutable"), (.isAppendOnly, "isAppendOnly"), 
            (.noDump, "noDump"), (.isEncrypted, "isEncrypted"), (.isAutoMount, "isAutoMount"), 
            (.isMountRoot, "isMountRoot"), (.isVerityProtected, "isVerityProtected"), (.isDAX, "isDAX")
        ]
    }
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