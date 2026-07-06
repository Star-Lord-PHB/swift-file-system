import PlatformCLib


extension PlatformFileAttributes {

    #if !(canImport(Darwin) || os(FreeBSD) || os(OpenBSD))
    @available(*, unavailable, message: "Only available on Darwin and BSD platforms")
    #endif
    public enum BSD {

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

        @inlinable public static var noDump: PlatformFileAttributes { .init(rawValue: .init(UF_NODUMP)) }
        @inlinable public static var isUserImmutable: PlatformFileAttributes { .init(rawValue: .init(UF_IMMUTABLE)) }
        @inlinable public static var isUserAppendOnly: PlatformFileAttributes { .init(rawValue: .init(UF_APPEND)) }
        @inlinable public static var isArchived: PlatformFileAttributes { .init(rawValue: .init(SF_ARCHIVED)) }
        @inlinable public static var isSystemImmutable: PlatformFileAttributes { .init(rawValue: .init(SF_IMMUTABLE)) }
        @inlinable public static var isSystemAppendOnly: PlatformFileAttributes { .init(rawValue: .init(SF_APPEND)) }

        #else

        @inline(never) public static var noDump: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUserImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUserAppendOnly: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isArchived: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystemImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystemAppendOnly: PlatformFileAttributes { fatalError() }

        #endif

    }

    #if !canImport(Darwin)
    @available(*, unavailable, message: "Only available on Darwin platforms")
    #endif
    public enum Darwin {

        #if canImport(Darwin)

        @inlinable public static var noDump: PlatformFileAttributes { .init(rawValue: .init(UF_NODUMP)) }
        @inlinable public static var isUserImmutable: PlatformFileAttributes { .init(rawValue: .init(UF_IMMUTABLE)) }
        @inlinable public static var isUserAppendOnly: PlatformFileAttributes { .init(rawValue: .init(UF_APPEND)) }
        @inlinable public static var isArchived: PlatformFileAttributes { .init(rawValue: .init(SF_ARCHIVED)) }
        @inlinable public static var isSystemImmutable: PlatformFileAttributes { .init(rawValue: .init(SF_IMMUTABLE)) }
        @inlinable public static var isSystemAppendOnly: PlatformFileAttributes { .init(rawValue: .init(SF_APPEND)) }

        @inlinable public static var isHidden: PlatformFileAttributes { .init(rawValue: .init(UF_HIDDEN)) }
        @inlinable public static var isOpaque: PlatformFileAttributes { .init(rawValue: .init(UF_OPAQUE)) }
        @inlinable public static var systemNoUnlink: PlatformFileAttributes { .init(rawValue: .init(SF_NOUNLINK)) }

        @inlinable public static var isCompressed: PlatformFileAttributes { .init(rawValue: .init(UF_COMPRESSED)) }
        @inlinable public static var isTracked: PlatformFileAttributes { .init(rawValue: .init(UF_TRACKED)) }
        @inlinable public static var isDataVault: PlatformFileAttributes { .init(rawValue: .init(UF_DATAVAULT)) }
        @inlinable public static var isRestricted: PlatformFileAttributes { .init(rawValue: .init(SF_RESTRICTED)) }
        @inlinable public static var isFirmLink: PlatformFileAttributes { .init(rawValue: .init(SF_FIRMLINK)) }
        @inlinable public static var isDataLess: PlatformFileAttributes { .init(rawValue: .init(SF_DATALESS)) }

        #else 

        @inline(never) public static var noDump: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUserImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUserAppendOnly: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isArchived: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystemImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystemAppendOnly: PlatformFileAttributes { fatalError() }

        @inline(never) public static var isHidden: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isOpaque: PlatformFileAttributes { fatalError() }
        @inline(never) public static var systemNoUnlink: PlatformFileAttributes { fatalError() }

        @inline(never) public static var isCompressed: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isTracked: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isDataVault: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isRestricted: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isFirmLink: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isDataLess: PlatformFileAttributes { fatalError() }

        #endif

    }

    #if !os(FreeBSD)
    @available(*, unavailable, message: "Only available on FreeBSD")
    #endif  
    public enum FreeBSD {

        #if os(FreeBSD)

        @inlinable public static var noDump: PlatformFileAttributes { .init(rawValue: .init(UF_NODUMP)) }
        @inlinable public static var isUserImmutable: PlatformFileAttributes { .init(rawValue: .init(UF_IMMUTABLE)) }
        @inlinable public static var isUserAppendOnly: PlatformFileAttributes { .init(rawValue: .init(UF_APPEND)) }
        @inlinable public static var isArchived: PlatformFileAttributes { .init(rawValue: .init(SF_ARCHIVED)) }
        @inlinable public static var isSystemImmutable: PlatformFileAttributes { .init(rawValue: .init(SF_IMMUTABLE)) }
        @inlinable public static var isSystemAppendOnly: PlatformFileAttributes { .init(rawValue: .init(SF_APPEND)) }

        @inlinable public static var isHidden: PlatformFileAttributes { .init(rawValue: .init(UF_HIDDEN)) }
        @inlinable public static var isOpaque: PlatformFileAttributes { .init(rawValue: .init(UF_OPAQUE)) }
        @inlinable public static var systemNoUnlink: PlatformFileAttributes { .init(rawValue: .init(SF_NOUNLINK)) }

        @inlinable public static var userNoUnlink: PlatformFileAttributes { .init(rawValue: .init(UF_NOUNLINK)) }
        @inlinable public static var isOffline: PlatformFileAttributes { .init(rawValue: .init(UF_OFFLINE)) }
        @inlinable public static var isReadOnly: PlatformFileAttributes { .init(rawValue: .init(UF_READONLY)) }
        @inlinable public static var isReparse: PlatformFileAttributes { .init(rawValue: .init(UF_REPARSE)) }
        @inlinable public static var isSparse: PlatformFileAttributes { .init(rawValue: .init(UF_SPARSE)) }
        @inlinable public static var isSystem: PlatformFileAttributes { .init(rawValue: .init(UF_SYSTEM)) }
        @inlinable public static var isSnapshot: PlatformFileAttributes { .init(rawValue: .init(SF_SNAPSHOT)) }

        #else 

        @inline(never) public static var noDump: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUserImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUserAppendOnly: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isArchived: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystemImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystemAppendOnly: PlatformFileAttributes { fatalError() }

        @inline(never) public static var isHidden: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isOpaque: PlatformFileAttributes { fatalError() }
        @inline(never) public static var systemNoUnlink: PlatformFileAttributes { fatalError() }

        @inline(never) public static var userNoUnlink: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isOffline: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isReadOnly: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isReparse: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSparse: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystem: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSnapshot: PlatformFileAttributes { fatalError() }

        #endif

    }

    #if !os(OpenBSD)
    @available(*, unavailable, message: "Only available on OpenBSD")
    #endif
    public enum OpenBSD {

        #if os(OpenBSD)

        @inlinable public static var noDump: PlatformFileAttributes { .init(rawValue: .init(UF_NODUMP)) }
        @inlinable public static var isUserImmutable: PlatformFileAttributes { .init(rawValue: .init(UF_IMMUTABLE)) }
        @inlinable public static var isUserAppendOnly: PlatformFileAttributes { .init(rawValue: .init(UF_APPEND)) }
        @inlinable public static var isArchived: PlatformFileAttributes { .init(rawValue: .init(SF_ARCHIVED)) }
        @inlinable public static var isSystemImmutable: PlatformFileAttributes { .init(rawValue: .init(SF_IMMUTABLE)) }
        @inlinable public static var isSystemAppendOnly: PlatformFileAttributes { .init(rawValue: .init(SF_APPEND)) }

        #else 

        @inline(never) public static var noDump: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUserImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUserAppendOnly: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isArchived: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystemImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystemAppendOnly: PlatformFileAttributes { fatalError() }

        #endif

    }

    #if !(canImport(Darwin) || os(FreeBSD) || os(OpenBSD))
    @available(*, unavailable, message: "Only available on Darwin and BSD platforms")
    #endif
    @inlinable public static var bsd: BSD.Type { BSD.self }

    #if !(canImport(Darwin))
    @available(*, unavailable, message: "Only available on Darwin platforms")
    #endif
    @inlinable public static var darwin: Darwin.Type { Darwin.self }

    #if !(os(FreeBSD))
    @available(*, unavailable, message: "Only available on FreeBSD")
    #endif
    @inlinable public static var freebsd: FreeBSD.Type { FreeBSD.self }

    #if !(os(OpenBSD))
    @available(*, unavailable, message: "Only available on OpenBSD")
    #endif
    @inlinable public static var openbsd: OpenBSD.Type { OpenBSD.self }

}



#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

extension PlatformFileAttributes {

    @usableFromInline static var _allWithNameAsArray: [(PlatformFileAttributes, StaticString)]? {
    #if canImport(Darwin)
        [
            (.darwin.noDump, "noDump"), (.darwin.isUserImmutable, "isUserImmutable"), (.darwin.isUserAppendOnly, "isUserAppendOnly"),
            (.darwin.isArchived, "isArchived"), (.darwin.isSystemImmutable, "isSystemImmutable"), (.darwin.isSystemAppendOnly, "isSystemAppendOnly"),
            (.darwin.isHidden, "isHidden"), (.darwin.isOpaque, "isOpaque"), (.darwin.systemNoUnlink, "systemNoUnlink"), (.darwin.isCompressed, "isCompressed"),
            (.darwin.isTracked, "isTracked"), (.darwin.isDataVault, "isDataVault"), (.darwin.isRestricted, "isRestricted"),
            (.darwin.isFirmLink, "isFirmLink"), (.darwin.isDataLess, "isDataLess")
        ]
    #elseif os(FreeBSD)
        [
            (.freebsd.noDump, "noDump"), (.freebsd.isUserImmutable, "isUserImmutable"), (.freebsd.isUserAppendOnly, "isUserAppendOnly"),
            (.freebsd.isArchived, "isArchived"), (.freebsd.isSystemImmutable, "isSystemImmutable"), (.freebsd.isSystemAppendOnly, "isSystemAppendOnly"),
            (.freebsd.isHidden, "isHidden"), (.freebsd.isOpaque, "isOpaque"), (.freebsd.systemNoUnlink, "systemNoUnlink"), (.freebsd.userNoUnlink, "userNoUnlink"),
            (.freebsd.isOffline, "isOffline"), (.freebsd.isReadOnly, "isReadOnly"), (.freebsd.isReparse, "isReparse"),
            (.freebsd.isSparse, "isSparse"), (.freebsd.isSystem, "isSystem"), (.freebsd.isSnapshot, "isSnapshot")
        ]
    #elseif os(OpenBSD)
        [
            (.openbsd.noDump, "noDump"), (.openbsd.isUserImmutable, "isUserImmutable"), (.openbsd.isUserAppendOnly, "isUserAppendOnly"),
            (.openbsd.isArchived, "isArchived"), (.openbsd.isSystemImmutable, "isSystemImmutable"), (.openbsd.isSystemAppendOnly, "isSystemAppendOnly")
        ]
    #endif 
    }

#if canImport(Darwin)
    @usableFromInline static let _all: Self = [
        .darwin.noDump, .darwin.isUserImmutable, .darwin.isUserAppendOnly, .darwin.isArchived, .darwin.isSystemImmutable, .darwin.isSystemAppendOnly, .darwin.isHidden, .darwin.isOpaque,
        .darwin.systemNoUnlink, .darwin.isCompressed, .darwin.isTracked, .darwin.isDataVault, .darwin.isRestricted, .darwin.isFirmLink, .darwin.isDataLess
    ]
#elseif os(FreeBSD)
    @usableFromInline static let _all: Self = [
        .freebsd.noDump, .freebsd.isUserImmutable, .freebsd.isUserAppendOnly, .freebsd.isArchived, .freebsd.isSystemImmutable, .freebsd.isSystemAppendOnly, .freebsd.isHidden, .freebsd.isOpaque,
        .freebsd.systemNoUnlink, .freebsd.userNoUnlink, .freebsd.isOffline, .freebsd.isReadOnly, .freebsd.isReparse, .freebsd.isSparse, .freebsd.isSystem, .freebsd.isSnapshot
    ]
#elseif os(OpenBSD)
    @usableFromInline static let _all: Self = [
        .openbsd.noDump, .openbsd.isUserImmutable, .openbsd.isUserAppendOnly, .openbsd.isArchived, .openbsd.isSystemImmutable, .openbsd.isSystemAppendOnly
    ]
#endif

}



extension PlatformFileAttributes {

    #if os(FreeBSD)
    var _isReadOnly: Bool? {
        get { contains(.freebsd.isReadOnly) }
        set {
            switch newValue {
                case true: insert(.freebsd.isReadOnly)
                case false: remove(.freebsd.isReadOnly)
                case .none: break
            }
        }
    }
    #endif 

    @inlinable
    var _isImmutable: Bool? {
        get { contains(.bsd.isUserImmutable) || contains(.bsd.isSystemImmutable) }
        set {
            switch newValue {
                case true: insert(.bsd.isUserImmutable)
                case false: 
                    remove(.bsd.isUserImmutable)
                    remove(.bsd.isSystemImmutable)
                case .none: break
            }
        }
    }

    #if canImport(Darwin)
    @inlinable
    var _isCompressed: Bool? {
        contains(.darwin.isCompressed)
    }
    #endif

    @inlinable
    var _isAppendOnly: Bool? {
        get { contains(.bsd.isUserAppendOnly) || contains(.bsd.isSystemAppendOnly) }
        set { 
            switch newValue {
                case true: insert(.bsd.isUserAppendOnly)
                case false: 
                    remove(.bsd.isUserAppendOnly)
                    remove(.bsd.isSystemAppendOnly)
                case .none: break
            }
        }
    }

}

#endif 