import SystemPackage
import PlatformCLib



public struct UnsafeSystemHandle: ~Copyable {

    #if canImport(WinSDK)
    public typealias SystemHandleType = WinSDK.HANDLE
    #else 
    public typealias SystemHandleType = CInt
    #endif

    public let unsafeRawHandle: SystemHandleType


    public init(owningRawHandle handle: SystemHandleType) {
        self.unsafeRawHandle = handle
    }


    deinit {
        try? Self._close(unsafeRawHandle)
    }


    public consuming func take() -> SystemHandleType {
        let handle = self.unsafeRawHandle
        discard self
        return handle
    }


    package func unownedHandle() -> UnsafeUnownedSystemHandle {
        return .init(unsafeRawHandle: unsafeRawHandle)
    }


    public consuming func close() throws(LowLevelError) {
        let handle = self.unsafeRawHandle
        discard self
        try Self._close(handle)
    }


    private static func _close(_ handle: SystemHandleType) throws(LowLevelError) {

        #if canImport(WinSDK)
        try execThrowingCFunction {
            CloseHandle(handle)
        }
        #else 
        try execThrowingCFunction {
            PlatformCLib.close(handle)
        }
        #endif

    }


    #if !canImport(WinSDK)
    public func setNonBlocking(_ value: Bool) throws(LowLevelError) {

        var flags = fcntl(unsafeRawHandle, F_GETFL)
        guard flags >= 0 else {
            try LowLevelError.assertError()
        }

        if value {
            flags |= O_NONBLOCK
        } else {
            flags &= ~O_NONBLOCK
        }
        
        try execThrowingCFunction {
            fcntl(unsafeRawHandle, F_SETFL, flags)
        }

    }
    #endif


    public func withUnsafeRawHandle<T: ~Copyable, E: Error>(_ operation: (SystemHandleType) throws(E) -> T) throws(E) -> T {
        return try operation(unsafeRawHandle)
    }

}


package struct UnsafeUnownedSystemHandle: ~Escapable {

    #if canImport(WinSDK)
    public typealias SystemHandleType = WinSDK.HANDLE
    #else 
    public typealias SystemHandleType = CInt
    #endif

    package let unsafeRawHandle: SystemHandleType

    package func unsafeTemporaryConvertingToOwning<R: ~Copyable, E: Error>(
        _ operation: (borrowing UnsafeSystemHandle) throws(E) -> R
    ) throws(E) -> R {
        let unsafeTmpHandle = UnsafeSystemHandle(owningRawHandle: unsafeRawHandle)
        do {
            let r = try operation(unsafeTmpHandle)
            _ = unsafeTmpHandle.take()      // This consumes the tmp handle without closing it
            return r
        } catch {
            _ = unsafeTmpHandle.take()      // This consumes the tmp handle without closing it
            throw error
        }
    }

}



extension UnsafeSystemHandle {

    public struct OpenOptions: Sendable {

        #if canImport(WinSDK)
        public typealias FlagType = DWORD
        #else
        public typealias FlagType = CInt
        #endif


        public enum CreationOptions: Sendable {
            case never
            case createIfMissing 
            case assertMissing
        }


        public enum AccessMode: Sendable {
            case readOnly(metadataOnly: Bool = false)
            case writeOnly(metadataOnly: Bool = false)
            case readWrite(metadataOnly: Bool = false)
            case none
        }


        public struct NativeAccessModeFlag: OptionSet, Sendable {

            public var rawValue: FlagType
            public init(rawValue: FlagType) {
                self.rawValue = rawValue
            }

            public static var windows: Windows.Type { Windows.self }
            public static var posix: Posix.Type { Posix.self }

            public enum Posix {
                #if !canImport(WinSDK)
                #if !(canImport(Darwin) || os(OpenBSD))
                public static var path: NativeAccessModeFlag { .init(rawValue: __O_PATH) }
                #else
                public static var path: NativeAccessModeFlag { .init(rawValue: 0) }
                #endif
                #else
                public static var path: NativeAccessModeFlag { .init(rawValue: 0) }
                #endif
            }

            public enum Windows {
                #if canImport(WinSDK)
                public static var readAttributes: NativeAccessModeFlag { .init(rawValue: DWORD(FILE_READ_ATTRIBUTES)) }
                public static var readControl: NativeAccessModeFlag { .init(rawValue: DWORD(READ_CONTROL)) }
                public static var genericRead: NativeAccessModeFlag { .init(rawValue: DWORD(GENERIC_READ)) }
                public static var writeAttributes: NativeAccessModeFlag { .init(rawValue: DWORD(FILE_WRITE_ATTRIBUTES)) }
                public static var writeDac: NativeAccessModeFlag { .init(rawValue: DWORD(WRITE_DAC)) }
                public static var writeOwner: NativeAccessModeFlag { .init(rawValue: DWORD(WRITE_OWNER)) }
                public static var genericWrite: NativeAccessModeFlag { .init(rawValue: DWORD(GENERIC_WRITE)) }
                public static var appendData: NativeAccessModeFlag { .init(rawValue: DWORD(FILE_APPEND_DATA)) }
                #else
                public static var readAttributes: NativeAccessModeFlag { .init(rawValue: 0) }
                public static var readControl: NativeAccessModeFlag { .init(rawValue: 0) }
                public static var genericRead: NativeAccessModeFlag { .init(rawValue: 0) }
                public static var writeAttributes: NativeAccessModeFlag { .init(rawValue: 0) }
                public static var writeDac: NativeAccessModeFlag { .init(rawValue: 0) }
                public static var writeOwner: NativeAccessModeFlag { .init(rawValue: 0) }
                public static var genericWrite: NativeAccessModeFlag { .init(rawValue: 0) }
                public static var appendData: NativeAccessModeFlag { .init(rawValue: 0) }
                #endif
            }

        }


        public struct NativeCreationFlag: RawRepresentable, Sendable {

            public var rawValue: FlagType
            public init(rawValue: FlagType) {
                self.rawValue = rawValue
            }

            public static var windows: Windows.Type { Windows.self }
            public static var posix: Posix.Type { Posix.self }

            public enum Posix {
                #if !canImport(WinSDK)
                public static var create: NativeCreationFlag { .init(rawValue: O_CREAT) }
                public static var exclusiveCreate: NativeCreationFlag { .init(rawValue: O_EXCL | O_CREAT) }
                #else
                @available(*, unavailable, message: "Not available on Windows")
                public static var create: NativeCreationFlag { fatalError() }
                @available(*, unavailable, message: "Not available on Windows")
                public static var exclusiveCreate: NativeCreationFlag { fatalError() }
                #endif
            }

            public enum Windows {
                #if canImport(WinSDK)
                public static var openExisting: NativeCreationFlag { .init(rawValue: DWORD(OPEN_EXISTING)) }
                public static var truncateExisting: NativeCreationFlag { .init(rawValue: DWORD(TRUNCATE_EXISTING)) }
                public static var openAlways: NativeCreationFlag { .init(rawValue: DWORD(OPEN_ALWAYS)) }
                public static var createAlways: NativeCreationFlag { .init(rawValue: DWORD(CREATE_ALWAYS)) }
                public static var createNew: NativeCreationFlag { .init(rawValue: DWORD(CREATE_NEW)) }
                #else
                @available(*, unavailable, message: "Not available on POSIX")
                public static var openExisting: NativeCreationFlag { fatalError() }
                @available(*, unavailable, message: "Not available on POSIX")
                public static var truncateExisting: NativeCreationFlag { fatalError() }
                @available(*, unavailable, message: "Not available on POSIX")
                public static var openAlways: NativeCreationFlag { fatalError() }
                @available(*, unavailable, message: "Not available on POSIX")
                public static var createAlways: NativeCreationFlag { fatalError() }
                @available(*, unavailable, message: "Not available on POSIX")
                public static var createNew: NativeCreationFlag { fatalError() }
                #endif
            }

        }


        public struct NativeOpenFlag: OptionSet, Sendable {

            public var rawValue: FlagType
            public init(rawValue: FlagType) {
                self.rawValue = rawValue
            }

            public static var windows: Windows.Type { Windows.self }
            public static var posix: Posix.Type { Posix.self }

            public enum Posix {
                #if !canImport(WinSDK)
                public static var truncate: NativeOpenFlag { .init(rawValue: O_TRUNC) }
                public static var append: NativeOpenFlag { .init(rawValue: O_APPEND) }
                public static var noFollow: NativeOpenFlag { .init(rawValue: O_NOFOLLOW) }
                public static var closeOnExec: NativeOpenFlag { .init(rawValue: O_CLOEXEC) }
                public static var nonBlocking: NativeOpenFlag { .init(rawValue: O_NONBLOCK) }
                public static var noCtty: NativeOpenFlag { .init(rawValue: O_NOCTTY) }
                public static var directory: NativeOpenFlag { .init(rawValue: O_DIRECTORY) }
                #else
                public static var truncate: NativeOpenFlag { .init(rawValue: 0) }
                public static var append: NativeOpenFlag { .init(rawValue: 0) }
                public static var noFollow: NativeOpenFlag { .init(rawValue: 0) }
                public static var closeOnExec: NativeOpenFlag { .init(rawValue: 0) }
                public static var nonBlocking: NativeOpenFlag { .init(rawValue: 0) }
                public static var noCtty: NativeOpenFlag { .init(rawValue: 0) }
                public static var directory: NativeOpenFlag { .init(rawValue: 0) }
                #endif
            }

            public enum Windows {
                #if canImport(WinSDK)
                public static var openReparsePoint: NativeOpenFlag { .init(rawValue: DWORD(FILE_FLAG_OPEN_REPARSE_POINT)) }
                public static var overlappedIO: NativeOpenFlag { .init(rawValue: DWORD(FILE_FLAG_OVERLAPPED)) }
                public static var backupSemantics: NativeOpenFlag { .init(rawValue: DWORD(FILE_FLAG_BACKUP_SEMANTICS)) }
                #else
                public static var openReparsePoint: NativeOpenFlag { .init(rawValue: 0) }
                public static var overlappedIO: NativeOpenFlag { .init(rawValue: 0) }
                public static var backupSemantics: NativeOpenFlag { .init(rawValue: 0) }
                #endif
            }

        }


        public struct WindowsNativeShareMode: OptionSet, Sendable {

            public var rawValue: FlagType
            public init(rawValue: FlagType) {
                self.rawValue = rawValue
            }

            #if canImport(WinSDK)
            public static var read: WindowsNativeShareMode { .init(rawValue: DWORD(FILE_SHARE_READ)) }
            public static var write: WindowsNativeShareMode { .init(rawValue: DWORD(FILE_SHARE_WRITE)) }
            public static var delete: WindowsNativeShareMode { .init(rawValue: DWORD(FILE_SHARE_DELETE)) }
            #else
            public static var read: WindowsNativeShareMode { .init(rawValue: 0) }
            public static var write: WindowsNativeShareMode { .init(rawValue: 0) }
            public static var delete: WindowsNativeShareMode { .init(rawValue: 0) }
            #endif

        }


        public struct NativeFlagDiff<NativeFlagType: OptionSet>: Sendable where NativeFlagType.RawValue == FlagType {

            public private(set) var inserted: FlagType = 0
            public private(set) var removed: FlagType = 0

            public init(rawInserted: FlagType = 0, rawRemoved: FlagType = 0) {
                self.remove(rawRemoved)
                self.insert(rawInserted) 
            }

            public init(inserted: NativeFlagType = [], removed: NativeFlagType = []) {
                self.remove(removed)
                self.insert(inserted) 
            }

            public init() {}

            public static func inserted(_ flags: NativeFlagType) -> NativeFlagDiff {
                return .init(inserted: flags)
            }

            public static func removed(_ flags: NativeFlagType) -> NativeFlagDiff {
                return .init(removed: flags)
            }

            func apply(to flags: FlagType, mask: FlagType) -> FlagType {
                return (flags | (inserted & mask)) & ~(removed & mask)
            }

            public mutating func insert(_ flags: FlagType) {
                inserted |= flags
                removed ^= (removed & flags)
            }

            public mutating func remove(_ flags: FlagType) {
                inserted ^= (inserted & flags)
                removed |= flags
            }

            public mutating func insert(_ flags: NativeFlagType) {
                self.insert(flags.rawValue)
            }

            public mutating func remove(_ flags: NativeFlagType) {
                self.remove(flags.rawValue)
            }

        }


        public var access: AccessMode
        public var creation: CreationOptions
        public var truncate: Bool
        public var append: Bool 
        public var noFollow: Bool 
        public var closeOnExec: Bool
        public var noBlocking: Bool 

        public var platformAccessModeFlagsDiff: NativeFlagDiff<NativeAccessModeFlag>
        public var platformCreationFlagsOverride: NativeCreationFlag?
        public var platformOpenFlagsDiff: NativeFlagDiff<NativeOpenFlag>

        public var windowsShareMode: WindowsNativeShareMode

        public init(
            access: AccessMode = .readOnly(),
            creation: CreationOptions = .never, 
            truncate: Bool = false, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true, 
            noBlocking: Bool = false, 
            platformAccessModeFlagsDiff: NativeFlagDiff<NativeAccessModeFlag> = .init(),
            platformCreationFlagsOverride: NativeCreationFlag? = nil,
            platformOpenFlagsDiff: NativeFlagDiff<NativeOpenFlag> = .init(),
            windowsShareMode: WindowsNativeShareMode = [.read, .write, .delete]
        ) {
            self.access = access
            self.creation = creation
            self.truncate = truncate
            self.append = append
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
            self.noBlocking = noBlocking
            self.platformAccessModeFlagsDiff = platformAccessModeFlagsDiff
            self.platformCreationFlagsOverride = platformCreationFlagsOverride
            self.platformOpenFlagsDiff = platformOpenFlagsDiff
            self.windowsShareMode = windowsShareMode
        }


        public var accessModeFlags: FlagType {

            #if canImport(WinSDK)

            var readMetaFlags: FlagType { .init(bitPattern: FILE_READ_ATTRIBUTES | READ_CONTROL) }
            var writeMetaFlags: FlagType {
                // Note: On Windows, READ_CONTROL is still required even when writing metadata such as DACL
                .init(bitPattern: FILE_WRITE_ATTRIBUTES | WRITE_DAC | WRITE_OWNER | READ_CONTROL)
            }
            
            var flags = switch access {
                case .readOnly(metadataOnly: true):    readMetaFlags
                case .readOnly:                        GENERIC_READ | readMetaFlags
                case .writeOnly(metadataOnly: true):   writeMetaFlags
                case .writeOnly where append:          FlagType(bitPattern: FILE_APPEND_DATA) | writeMetaFlags
                case .writeOnly:                       FlagType(bitPattern: GENERIC_WRITE) | writeMetaFlags
                case .readWrite(metadataOnly: true):   readMetaFlags | writeMetaFlags
                case .readWrite where append:          GENERIC_READ | FlagType(bitPattern: FILE_APPEND_DATA) | readMetaFlags | writeMetaFlags
                case .readWrite:                       GENERIC_READ | FlagType(bitPattern: GENERIC_WRITE) | readMetaFlags | writeMetaFlags
                case .none:                            0 as FlagType
            }

            if truncate {
                flags |= FlagType(bitPattern: GENERIC_WRITE)
            }

            return platformAccessModeFlagsDiff.apply(to: flags, mask: ~0)

            #else

            let flags = switch access {
                #if !(canImport(Darwin) || os(OpenBSD))      // O_PATH is not available on OpenBSD or macOS
                case .readOnly(metadataOnly: true): O_RDONLY | __O_PATH
                case .writeOnly(metadataOnly: true): O_WRONLY | __O_PATH
                case .readWrite(metadataOnly: true): O_RDWR | __O_PATH
                #endif
                case .readOnly:                     O_RDONLY
                case .writeOnly:                    O_WRONLY
                case .readWrite:                    O_RDWR
                #if !(canImport(Darwin) || os(OpenBSD))
                case .none:                         O_RDONLY | __O_PATH
                #else
                case .none:                         O_RDONLY
                #endif
            } as FlagType

            #if !(canImport(Darwin) || os(OpenBSD))      // O_PATH is not available on OpenBSD or macOS
            let mask = O_ACCMODE | __O_PATH
            #else
            let mask = O_ACCMODE
            #endif

            return platformAccessModeFlagsDiff.apply(to: flags, mask: mask)

            #endif

        }

        public var creationFlags: FlagType {

            #if canImport(WinSDK)

            if let platformCreationFlagsOverride {
                return platformCreationFlagsOverride.rawValue
            }

            return switch (creation, truncate) {
                case (.never, false):           FlagType(bitPattern: OPEN_EXISTING)
                case (.never, true):            FlagType(bitPattern: TRUNCATE_EXISTING)
                case (.createIfMissing, false): FlagType(bitPattern: OPEN_ALWAYS)
                case (.createIfMissing, true):  FlagType(bitPattern: CREATE_ALWAYS)
                case (.assertMissing, _):       FlagType(bitPattern: CREATE_NEW)
            }

            #else 

            if let platformCreationFlagsOverride {
                return platformCreationFlagsOverride.rawValue & (O_EXCL | O_CREAT)
            }

            return switch creation {
                case .never:            0
                case .createIfMissing:  O_CREAT
                case .assertMissing:    O_EXCL | O_CREAT
            }

            #endif

        }

        public var openFlags: FlagType {

            var flags = 0 as FlagType

            #if canImport(WinSDK)

            flags |= FlagType(bitPattern: FILE_ATTRIBUTE_NORMAL)
            if noFollow { flags |= FlagType(bitPattern: FILE_FLAG_OPEN_REPARSE_POINT) }
            if noBlocking { flags |= FlagType(bitPattern: FILE_FLAG_OVERLAPPED) }

            return platformOpenFlagsDiff.apply(to: flags, mask: ~0)

            #else 

            if truncate { flags |= O_TRUNC }
            if append { flags |= O_APPEND }
            #if canImport(Darwin)       // on Darwin, O_SYMLINK is used to avoid following symlinks
            if noFollow { flags |= O_SYMLINK }
            #else                       // on other POSIX systems, O_NOFOLLOW is used, but will fail if not used with O_PATH
            if noFollow { flags |= O_NOFOLLOW }
            #endif 
            if closeOnExec { flags |= O_CLOEXEC }
            if noBlocking { flags |= O_NONBLOCK }

            #if !(canImport(Darwin) || os(OpenBSD))
            let mask = ~(O_ACCMODE | __O_PATH | O_CREAT | O_EXCL)
            #else
            let mask = ~(O_ACCMODE | O_CREAT | O_EXCL)
            #endif

            return platformOpenFlagsDiff.apply(to: flags, mask: mask)

            #endif 

        }

        #if canImport(WinSDK)
        public var securityAttributes: SECURITY_ATTRIBUTES {
            var attrs = SECURITY_ATTRIBUTES()
            attrs.nLength = DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size)
            attrs.bInheritHandle = WindowsBool(!closeOnExec)
            attrs.lpSecurityDescriptor = nil
            return attrs
        }
        #endif 


        var willCreate: Bool {
            #if canImport(WinSDK)
            switch creationFlags {
                case DWORD(OPEN_ALWAYS), DWORD(CREATE_ALWAYS), DWORD(CREATE_NEW): true
                default: false
            }
            #else
            return creationFlags & O_CREAT != 0
            #endif
        }

    }

}
