import PlatformCLib
import CFileSystem


extension PlatformFileAttributes {

    #if !(canImport(Glibc) || canImport(Musl))
    @available(*, unavailable, message: "Only available on Linux platforms")
    #endif
    public enum Linux {

        #if canImport(Glibc) || canImport(Musl)

        @inlinable public static var isCompressed: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_COMPRESSED)) }
        @inlinable public static var isImmutable: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_IMMUTABLE)) }
        @inlinable public static var isAppendOnly: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_APPEND)) }
        @inlinable public static var noDump: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_NODUMP)) }
        @inlinable public static var isEncrypted: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_ENCRYPTED)) }
        @inlinable public static var isAutoMount: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_AUTOMOUNT)) }
        @inlinable public static var isMountRoot: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_MOUNT_ROOT)) }
        @inlinable public static var isVerityProtected: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_VERITY)) }
        @inlinable public static var isWriteAtomic: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_WRITE_ATOMIC)) }
        @inlinable public static var isDAX: PlatformFileAttributes { .init(rawValue: .init(STATX_ATTR_DAX)) }

        #else 

        @inline(never) public static var isCompressed: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isImmutable: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isAppendOnly: PlatformFileAttributes { fatalError() }
        @inline(never) public static var noDump: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isEncrypted: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isAutoMount: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isMountRoot: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isVerityProtected: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isWriteAtomic: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isDAX: PlatformFileAttributes { fatalError() }    
        
        #endif

    }

    #if !(canImport(Glibc) || canImport(Musl))
    @available(*, unavailable, message: "Only available on Linux platforms")
    #endif
    public static var linux: Linux.Type { Linux.self }

}



#if canImport(Glibc) || canImport(Musl)

extension PlatformFileAttributes {

    @usableFromInline
    static var _allWithNameAsArray: [(PlatformFileAttributes, StaticString)]? {
        [
            (.linux.isCompressed, "isCompressed"), (.linux.isImmutable, "isImmutable"), (.linux.isAppendOnly, "isAppendOnly"), 
            (.linux.noDump, "noDump"), (.linux.isEncrypted, "isEncrypted"), (.linux.isAutoMount, "isAutoMount"), 
            (.linux.isMountRoot, "isMountRoot"), (.linux.isVerityProtected, "isVerityProtected"), (.linux.isWriteAtomic, "isWriteAtomic"), (.linux.isDAX, "isDAX")
        ]
    }
    @usableFromInline static let _all: Self = [
        .linux.isCompressed, .linux.isImmutable, .linux.isAppendOnly, .linux.noDump, .linux.isEncrypted,
        .linux.isAutoMount, .linux.isMountRoot, .linux.isVerityProtected, .linux.isWriteAtomic, .linux.isDAX
    ]

}



extension PlatformFileAttributes {

    @inlinable
    var _isImmutable: Bool? {
        get { contains(.linux.isImmutable) }
        set {
            switch newValue {
                case true: insert(.linux.isImmutable)
                case false: remove(.linux.isImmutable)
                case .none: break
            }
        }
    }

    @inlinable
    var _isCompressed: Bool? {
        contains(.linux.isCompressed)
    }

    @inlinable
    var _isAppendOnly: Bool? {
        get { contains(.linux.isAppendOnly) }
        set {
            switch newValue {
                case true: insert(.linux.isAppendOnly)
                case false: remove(.linux.isAppendOnly)
                case .none: break
            }
        }
    }

    @inlinable
    var _isEncrypted: Bool? {
        contains(.linux.isEncrypted)
    }

}

#endif