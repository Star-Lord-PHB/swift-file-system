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
            case readOnly
            case writeOnly
            case readWrite
            case none
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
        /// Whether a symbolic link at the final path component is resolved.
        ///
        /// `true` (the default) resolves the link and opens its target. `false` never resolves it: the
        /// open addresses the link itself where the platform can hand out a handle to it and fails
        /// otherwise, so it never falls through to the target. This is the `lstat`-style semantic
        /// rather than POSIX `O_NOFOLLOW`, and the derived flag differs per platform:
        ///
        /// | Platform | Derived flag | Opening a symlink yields |
        /// | -- | -- | -- |
        /// | Windows | `FILE_FLAG_OPEN_REPARSE_POINT` | a handle to the link itself |
        /// | Darwin | `O_SYMLINK` | a handle to the link itself, with any access mode |
        /// | Linux | `O_NOFOLLOW` | a handle to the link itself only with `access == .none` (`O_PATH`); a data-access open fails with `ELOOP` |
        /// | OpenBSD (no `O_PATH`) | `O_NOFOLLOW` | always fails with `ELOOP` |
        ///
        /// A regular file opens the same way with either value. To reject symlinks outright
        /// (POSIX `O_NOFOLLOW` semantics), insert `.posix.noFollow` through ``platformOpenFlagsDiff``;
        /// Windows has no native equivalent, so callers open the link itself and check
        /// ``UnsafeSystemHandle/type()`` on the returned handle.
        public var followSymlink: Bool
        public var closeOnExec: Bool

        public var platformCreationFlagsOverride: NativeCreationFlag?
        public var platformOpenFlagsDiff: NativeFlagDiff<NativeOpenFlag>

        public var windowsExtraAccess: WindowsAccessMask
        public var windowsShareMode: WindowsNativeShareMode

        public init(
            access: AccessMode = .readOnly,
            creation: CreationOptions = .never, 
            truncate: Bool = false, 
            append: Bool = false, 
            followSymlink: Bool = true, 
            closeOnExec: Bool = true,
            platformCreationFlagsOverride: NativeCreationFlag? = nil,
            platformOpenFlagsDiff: NativeFlagDiff<NativeOpenFlag> = .init(),
            windowsExtraAccess: WindowsAccessMask = [],
            windowsShareMode: WindowsNativeShareMode = [.read, .write, .delete]
        ) {
            self.access = access
            self.creation = creation
            self.truncate = truncate
            self.append = append
            self.followSymlink = followSymlink
            self.closeOnExec = closeOnExec
            self.windowsExtraAccess = windowsExtraAccess
            self.platformCreationFlagsOverride = platformCreationFlagsOverride
            self.platformOpenFlagsDiff = platformOpenFlagsDiff
            self.windowsShareMode = windowsShareMode
        }


        public var accessModeFlags: FlagType {

            #if canImport(WinSDK)
            
            var flags = switch access {
                case .readOnly:                        GENERIC_READ
                case .writeOnly where append:          FILE_GENERIC_WRITE ^ FlagType(bitPattern: FILE_WRITE_DATA)
                case .writeOnly:                       FlagType(bitPattern: GENERIC_WRITE)
                case .readWrite where append:          GENERIC_READ | (FILE_GENERIC_WRITE ^ FlagType(bitPattern: FILE_WRITE_DATA))
                case .readWrite:                       GENERIC_READ | FlagType(bitPattern: GENERIC_WRITE)
                case .none:                            0 as FlagType
            }

            if truncate {
                flags |= FlagType(bitPattern: GENERIC_WRITE)
            }

            return flags | windowsExtraAccess.rawValue

            #else

            return switch access {
                #if !(canImport(Darwin) || os(OpenBSD))      // O_PATH is not available on OpenBSD or macOS
                case .none:      __O_PATH
                #else
                case .none:      O_RDONLY
                #endif
                case .readOnly:  O_RDONLY
                case .writeOnly: O_WRONLY
                case .readWrite: O_RDWR
            }

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
            if !followSymlink { flags |= FlagType(bitPattern: FILE_FLAG_OPEN_REPARSE_POINT) }     // opens the reparse point itself

            return platformOpenFlagsDiff.apply(to: flags, mask: ~0)

            #else 

            if truncate { flags |= O_TRUNC }
            if append { flags |= O_APPEND }
            #if canImport(Darwin)       // Darwin: O_SYMLINK opens the link itself with any access mode
            if !followSymlink { flags |= O_SYMLINK }
            #else                       // other POSIX: O_NOFOLLOW opens the link itself only with O_PATH, otherwise fails with ELOOP
            if !followSymlink { flags |= O_NOFOLLOW }
            #endif 
            if closeOnExec { flags |= O_CLOEXEC }

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

        package var estimatedMappedWindowsAccess: WindowsAccessMask {
            var mappedAccess = WindowsAccessMask(rawValue: accessModeFlags)
            mappedAccess.insert([.readAttributes, .synchronize])
            if mappedAccess.contains(.genericRead) {
                mappedAccess.insert(.mappedGenericRead)
            }
            if mappedAccess.contains(.genericWrite) {
                mappedAccess.insert(.mappedGenericWrite)
            }
            if mappedAccess.contains(.genericExecute) {
                mappedAccess.insert(.mappedGenericExecute)
            }
            if mappedAccess.contains(.genericAll) {
                mappedAccess.insert(.mappedGenericRead)
                mappedAccess.insert(.mappedGenericWrite)
                mappedAccess.insert(.mappedGenericExecute)
            }
            return mappedAccess
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
