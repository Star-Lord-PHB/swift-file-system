#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

import PlatformCLib


extension FileInfo.PlatformAttributes {

    @inlinable public static var bitNoDump: RawBitType { .init(UF_NODUMP) }
    @inlinable public static var bitIsUserImmutable: RawBitType { .init(UF_IMMUTABLE) }
    @inlinable public static var bitIsUserAppendOnly: RawBitType { .init(UF_APPEND) }
    @inlinable public static var bitIsArchived: RawBitType { .init(SF_ARCHIVED) }
    @inlinable public static var bitIsSystemImmutable: RawBitType { .init(SF_IMMUTABLE) }
    @inlinable public static var bitIsSystemAppendOnly: RawBitType { .init(SF_APPEND) }

#if canImport(Darwin) || os(FreeBSD)
    @inlinable public static var bitIsHidden: RawBitType { .init(UF_HIDDEN) }
    @inlinable public static var bitIsOpaque: RawBitType { .init(UF_OPAQUE) }
    @inlinable public static var bitSystemNoUnlink: RawBitType { .init(SF_NOUNLINK) }
#endif

#if canImport(Darwin)
    @inlinable public static var bitIsCompressed: RawBitType { .init(UF_COMPRESSED) }
    @inlinable public static var bitIsTracked: RawBitType { .init(UF_TRACKED) }
    @inlinable public static var bitIsDataVault: RawBitType { .init(UF_DATAVAULT) }
    @inlinable public static var bitIsRestricted: RawBitType { .init(SF_RESTRICTED) }
    @inlinable public static var bitIsFirmLink: RawBitType { .init(SF_FIRMLINK) }
    @inlinable public static var bitIsDataLess: RawBitType { .init(SF_DATALESS) }
#endif

#if os(FreeBSD)
    @inlinable public static var bitUserNoUnlink: RawBitType { .init(UF_NOUNLINK) }
    @inlinable public static var bitIsOffline: RawBitType { .init(UF_OFFLINE) }
    @inlinable public static var bitIsReadOnly: RawBitType { .init(UF_READONLY) }
    @inlinable public static var bitIsReparse: RawBitType { .init(UF_REPARSE) }
    @inlinable public static var bitIsSparse: RawBitType { .init(UF_SPARSE) }
    @inlinable public static var bitIsSystem: RawBitType { .init(UF_SYSTEM) }
    @inlinable public static var bitIsSnapshot: RawBitType { .init(SF_SNAPSHOT) }
#endif 


    @inlinable public static var noDump: Self { .init(rawValue: bitNoDump) }
    @inlinable public static var isUserImmutable: Self { .init(rawValue: bitIsUserImmutable) }
    @inlinable public static var isUserAppendOnly: Self { .init(rawValue: bitIsUserAppendOnly) }
    @inlinable public static var isArchived: Self { .init(rawValue: bitIsArchived) }
    @inlinable public static var isSystemImmutable: Self { .init(rawValue: bitIsSystemImmutable) }
    @inlinable public static var isSystemAppendOnly: Self { .init(rawValue: bitIsSystemAppendOnly) }

#if canImport(Darwin) || os(FreeBSD)
    @inlinable public static var isHidden: Self { .init(rawValue: bitIsHidden) }
    @inlinable public static var isOpaque: Self { .init(rawValue: bitIsOpaque) }
    @inlinable public static var systemNoUnlink: Self { .init(rawValue: bitSystemNoUnlink) }
#endif

#if canImport(Darwin)
    @inlinable public static var isCompressed: Self { .init(rawValue: bitIsCompressed) }
    @inlinable public static var isTracked: Self { .init(rawValue: bitIsTracked) }
    @inlinable public static var isDataVault: Self { .init(rawValue: bitIsDataVault) }
    @inlinable public static var isRestricted: Self { .init(rawValue: bitIsRestricted) }
    @inlinable public static var isFirmLink: Self { .init(rawValue: bitIsFirmLink) }
    @inlinable public static var isDataLess: Self { .init(rawValue: bitIsDataLess) }
#endif

#if os(FreeBSD)
    @inlinable public static var userNoUnlink: Self { .init(rawValue: bitUserNoUnlink) }
    @inlinable public static var isOffline: Self { .init(rawValue: bitIsOffline) }
    @inlinable public static var isReadOnly: Self { .init(rawValue: bitIsReadOnly) }
    @inlinable public static var isReparse: Self { .init(rawValue: bitIsReparse) }
    @inlinable public static var isSparse: Self { .init(rawValue: bitIsSparse) }
    @inlinable public static var isSystem: Self { .init(rawValue: bitIsSystem) }
    @inlinable public static var isSnapshot: Self { .init(rawValue: bitIsSnapshot) }
#endif


    @usableFromInline static var _allWithNameAsArray: [(Self, StaticString)]? {
    #if canImport(Darwin)
        [
            (.noDump, "noDump"), (.isUserImmutable, "isUserImmutable"), (.isUserAppendOnly, "isUserAppendOnly"),
            (.isArchived, "isArchived"), (.isSystemImmutable, "isSystemImmutable"), (.isSystemAppendOnly, "isSystemAppendOnly"),
            (.isHidden, "isHidden"), (.isOpaque, "isOpaque"), (.systemNoUnlink, "systemNoUnlink"), (.isCompressed, "isCompressed"),
            (.isTracked, "isTracked"), (.isDataVault, "isDataVault"), (.isRestricted, "isRestricted"),
            (.isFirmLink, "isFirmLink"), (.isDataLess, "isDataLess")
        ]
    #elseif os(FreeBSD)
        [
            (.noDump, "noDump"), (.isUserImmutable, "isUserImmutable"), (.isUserAppendOnly, "isUserAppendOnly"),
            (.isArchived, "isArchived"), (.isSystemImmutable, "isSystemImmutable"), (.isSystemAppendOnly, "isSystemAppendOnly"),
            (.isHidden, "isHidden"), (.isOpaque, "isOpaque"), (.systemNoUnlink, "systemNoUnlink"), (.userNoUnlink, "userNoUnlink"),
            (.isOffline, "isOffline"), (.isReadOnly, "isReadOnly"), (.isReparse, "isReparse"),
            (.isSparse, "isSparse"), (.isSystem, "isSystem"), (.isSnapshot, "isSnapshot")
        ]
    #elseif os(OpenBSD)
        [
            (.noDump, "noDump"), (.isUserImmutable, "isUserImmutable"), (.isUserAppendOnly, "isUserAppendOnly"),
            (.isArchived, "isArchived"), (.isSystemImmutable, "isSystemImmutable"), (.isSystemAppendOnly, "isSystemAppendOnly")
        ]
    #endif 
    }

#if canImport(Darwin)
    @usableFromInline static let _all: Self = [
        .noDump, .isUserImmutable, .isUserAppendOnly, .isArchived, .isSystemImmutable, .isSystemAppendOnly, .isHidden, .isOpaque,
        .systemNoUnlink, .isCompressed, .isTracked, .isDataVault, .isRestricted, .isFirmLink, .isDataLess
    ]
#elseif os(FreeBSD)
    @usableFromInline static let _all: Self = [
        .noDump, .isUserImmutable, .isUserAppendOnly, .isArchived, .isSystemImmutable, .isSystemAppendOnly, .isHidden, .isOpaque,
        .systemNoUnlink, .userNoUnlink, .isOffline, .isReadOnly, .isReparse, .isSparse, .isSystem, .isSnapshot
    ]
#elseif os(OpenBSD)
    @usableFromInline static let _all: Self = [
        .noDump, .isUserImmutable, .isUserAppendOnly, .isArchived, .isSystemImmutable, .isSystemAppendOnly
    ]
#endif

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

#if canImport(Darwin) || os(FreeBSD)
    @inlinable
    public var isHidden: Bool {
        get { (rawValue & Self.bitIsHidden) != 0 }
        set { set(newValue, for: Self.bitIsHidden) }
    }

    @inlinable
    public var isOpaque: Bool {
        get { (rawValue & Self.bitIsOpaque) != 0 }
        set { set(newValue, for: Self.bitIsOpaque) }
    }

    @inlinable
    public var systemNoUnlink: Bool {
        get { (rawValue & Self.bitSystemNoUnlink) != 0 }
        set { set(newValue, for: Self.bitSystemNoUnlink) }
    }
#endif

#if canImport(Darwin)
    @inlinable
    public var isCompressed: Bool {
        get { (rawValue & Self.bitIsCompressed != 0) }
        set { set(newValue, for: Self.bitIsCompressed) }
    }

    @inlinable
    public var isTracked: Bool {
        get { (rawValue & Self.bitIsTracked != 0) }
        set { set(newValue, for: Self.bitIsTracked) }
    }

    @inlinable
    public var isDataVault: Bool {
        get { (rawValue & Self.bitIsDataVault != 0) }
        set { set(newValue, for: Self.bitIsDataVault) }
    }

    @inlinable
    public var isRestricted: Bool {
        get { (rawValue & Self.bitIsRestricted != 0) }
        set { set(newValue, for: Self.bitIsRestricted) }
    }

    @inlinable
    public var isFirmLink: Bool {
        get { (rawValue & Self.bitIsFirmLink != 0) }
        set { set(newValue, for: Self.bitIsFirmLink) }
    }

    @inlinable
    public var isDataLess: Bool {
        get { (rawValue & Self.bitIsDataLess != 0) }
        set { set(newValue, for: Self.bitIsDataLess) }
    }
#endif

#if os(FreeBSD)
    @inlinable
    public var userNoUnlink: Bool {
        get { (rawValue & Self.bitUserNoUnlink) != 0 }
        set { set(newValue, for: Self.bitUserNoUnlink) }
    }

    @inlinable
    public var isOffline: Bool {
        get { (rawValue & Self.bitIsOffline) != 0 }
        set { set(newValue, for: Self.bitIsOffline) }
    }

    @inlinable
    public var isReadOnly: Bool {
        get { (rawValue & Self.bitIsReadOnly) != 0 }
        set { set(newValue, for: Self.bitIsReadOnly) }
    }

    @inlinable
    public var isReparse: Bool {
        get { (rawValue & Self.bitIsReparse) != 0 }
        set { set(newValue, for: Self.bitIsReparse) }
    }

    @inlinable
    public var isSparse: Bool {
        get { (rawValue & Self.bitIsSparse) != 0 }
        set { set(newValue, for: Self.bitIsSparse) }
    }

    @inlinable
    public var isSystem: Bool {
        get { (rawValue & Self.bitIsSystem) != 0 }
        set { set(newValue, for: Self.bitIsSystem) }
    }

    @inlinable
    public var isSnapshot: Bool {
        get { (rawValue & Self.bitIsSnapshot) != 0 }
        set { set(newValue, for: Self.bitIsSnapshot) }
    }
#endif

}

#endif 