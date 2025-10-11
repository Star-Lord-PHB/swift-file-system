import Foundation
import SystemPackage
import CFileSystem


extension FileInfo {

    public struct Attributes: Sendable, OptionSet {

    #if canImport(Glibc) || canImport(Musl)
        public typealias RawBitType = UInt64
    #elseif canImport(WinSDK)
        // TODO: implement on Windows
    #else 
        public typealias RawBitType = UInt32
    #endif


        public private(set) var rawValue: RawBitType


        public init(rawValue: RawBitType) {
            self.rawValue = rawValue
        }


        public mutating func set(_ value: Bool, for attr: RawBitType) {
            if value {
                rawValue |= attr
            } else {
                rawValue &= ~attr
            }
        }

    }

}



extension FileInfo.Attributes {

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