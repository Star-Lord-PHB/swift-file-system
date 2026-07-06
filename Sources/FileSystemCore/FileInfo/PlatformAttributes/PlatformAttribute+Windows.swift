import PlatformCLib


extension PlatformFileAttributes {

    #if !canImport(WinSDK)
    @available(*, unavailable, message: "Only available on Windows")
    #endif
    public enum Windows {

        #if canImport(WinSDK)

        @inlinable public static var isReadOnly: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_READONLY)) }
        @inlinable public static var isHidden: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_HIDDEN)) }
        @inlinable public static var isSystem: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_SYSTEM)) }
        @inlinable public static var isDirectory: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_DIRECTORY)) }
        @inlinable public static var isArchive: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_ARCHIVE)) }
        @inlinable public static var isDevice: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_DEVICE)) }
        @inlinable public static var isNormal: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_NORMAL)) }
        @inlinable public static var isTemporary: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_TEMPORARY)) }
        @inlinable public static var isSparseFile: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_SPARSE_FILE)) }
        @inlinable public static var isReparsePoint: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_REPARSE_POINT)) }
        @inlinable public static var isCompressed: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_COMPRESSED)) }
        @inlinable public static var isOffline: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_OFFLINE)) }
        @inlinable public static var isNotContentIndexed: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_NOT_CONTENT_INDEXED)) }
        @inlinable public static var isEncrypted: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_ENCRYPTED)) }
        @inlinable public static var isIntegrityStream: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_INTEGRITY_STREAM)) }
        @inlinable public static var isVirtual: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_VIRTUAL)) }
        @inlinable public static var isNoScrubData: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_NO_SCRUB_DATA)) }
        @inlinable public static var isPinned: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_PINNED)) }
        @inlinable public static var isUnpinned: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_UNPINNED)) }
        @inlinable public static var recallOnOpen: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_RECALL_ON_OPEN)) }
        @inlinable public static var recallOnDataAccess: PlatformFileAttributes { .init(rawValue: .init(FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS)) }

        #else 

        @inline(never) public static var isReadOnly: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isHidden: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSystem: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isDirectory: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isArchive: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isDevice: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isNormal: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isTemporary: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isSparseFile: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isReparsePoint: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isCompressed: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isOffline: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isNotContentIndexed: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isEncrypted: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isIntegrityStream: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isVirtual: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isNoScrubData: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isPinned: PlatformFileAttributes { fatalError() }
        @inline(never) public static var isUnpinned: PlatformFileAttributes { fatalError() }
        @inline(never) public static var recallOnOpen: PlatformFileAttributes { fatalError() }
        @inline(never) public static var recallOnDataAccess: PlatformFileAttributes { fatalError() }

        #endif 

    }

    #if !canImport(WinSDK)
    @available(*, unavailable, message: "Only available on Windows")
    #endif
    public static var windows: Windows.Type { Windows.self }

}



#if canImport(WinSDK)

extension PlatformFileAttributes {

    @usableFromInline
    static var _allWithNameAsArray: [(PlatformFileAttributes, StaticString)]? {
        [
            (.windows.isReadOnly, "isReadOnly"), (.windows.isHidden, "isHidden"), (.windows.isSystem, "isSystem"), (.windows.isDirectory, "isDirectory"), 
            (.windows.isArchive, "isArchive"), (.windows.isDevice, "isDevice"), (.windows.isNormal, "isNormal"), (.windows.isTemporary, "isTemporary"),
            (.windows.isSparseFile, "isSparseFile"), (.windows.isReparsePoint, "isReparsePoint"), (.windows.isCompressed, "isCompressed"),
            (.windows.isOffline, "isOffline"), (.windows.isNotContentIndexed, "isNotContentIndexed"), (.windows.isEncrypted, "isEncrypted"),
            (.windows.isIntegrityStream, "isIntegrityStream"), (.windows.isVirtual, "isVirtual"), (.windows.isNoScrubData, "isNoScrubData"),
            (.windows.isPinned, "isPinned"), (.windows.isUnpinned, "isUnpinned"), (.windows.recallOnOpen, "recallOnOpen"), (.windows.recallOnDataAccess, "recallOnDataAccess")
        ]
    }
    @usableFromInline static let _all: Self = [
        .windows.isReadOnly, .windows.isHidden, .windows.isSystem, .windows.isDirectory, .windows.isArchive, .windows.isDevice, .windows.isNormal,
        .windows.isTemporary, .windows.isSparseFile, .windows.isReparsePoint, .windows.isCompressed, .windows.isOffline,
        .windows.isNotContentIndexed, .windows.isEncrypted, .windows.isIntegrityStream, .windows.isVirtual, .windows.isNoScrubData,
        .windows.isPinned, .windows.isUnpinned, .windows.recallOnOpen, .windows.recallOnDataAccess
    ]

}



extension PlatformFileAttributes {

    @inlinable
    var _isReadOnly: Bool? {
        get { contains(.windows.isReadOnly) }
        set { 
            switch newValue {
                case true: insert(.windows.isReadOnly)
                case false: remove(.windows.isReadOnly)
                case .none: break
            }
        }
    }

    @inlinable
    var _isCompressed: Bool? {
        contains(.windows.isCompressed)
    }

    @inlinable
    var _isEncrypted: Bool? {
        contains(.windows.isEncrypted)
    }

}

#endif