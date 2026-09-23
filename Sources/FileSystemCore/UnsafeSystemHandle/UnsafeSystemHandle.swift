import SystemPackage
import PlatformCLib



/// Unsafe low-level wrapper of a system file handle / descriptor. 
public struct UnsafeSystemHandle: ~Copyable {

    #if canImport(WinSDK)
    public typealias SystemHandleType = WinSDK.HANDLE
    #else 
    public typealias SystemHandleType = CInt
    #endif

    package let unsafeRawHandle: SystemHandleType


    /// Create an instance by owning the lifetime of an raw handle / descriptor
    /// 
    /// - Parameter handle: The raw handle / descriptor to own
    /// 
    /// - Warning: The caller should ensure that this instance is the only owner of this handle
    ///            and the caller itself should not use this handle afterwards.
    public init(owningRawHandle handle: SystemHandleType) {
        self.unsafeRawHandle = handle
    }


    deinit {
        try? Self._close(unsafeRawHandle)
    }


    /// End the lifetime of this instance and get the raw handle / descriptor it manages.
    /// 
    /// - Returns: The raw handle / descriptor managed by this instance.
    /// 
    /// - Attention: The caller is responsible for managing the lifetime of the returned handle / descriptor
    public consuming func take() -> SystemHandleType {
        let handle = self.unsafeRawHandle
        discard self
        return handle
    }


    package func unownedHandle() -> UnsafeUnownedSystemHandle {
        return .init(unsafeRawHandle: unsafeRawHandle)
    }


    /// Close the handle / descriptor managed by this instance and end its lifetime.
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
    /// Set the non-blocking mode of the file handle
    /// 
    /// - Parameter value: Whether to enable non-blocking mode
    /// 
    /// It is mapped to toggling `O_NONBLOCK` with `fcntl`.
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


    /// Access the raw handle / descriptor managed by this instance in a closure.
    /// 
    /// - Parameter operation: The closure for accessing the raw handle / descriptor
    /// 
    /// - Warning: Do not return or store the received raw handle / descriptor outside the closure
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

    /// Options for opening an ``UnsafeSystemHandle``
    public struct OpenOptions: Sendable {

        #if canImport(WinSDK)
        public typealias FlagType = DWORD
        #else
        public typealias FlagType = CInt
        #endif


        /// Access mode for opening a file handle
        /// 
        /// |  | Windows | Darwin & OpenBSD | Linux |
        /// | -- | -- | -- | -- |
        /// | readOnly | `GENERIC_READ` | `O_RDONLY` | `O_RDONLY` |
        /// | writeOnly | `GENERIC_WRITE` | `O_WRONLY` | `O_WRONLY` |
        /// | readWrite | `GENERIC_READ \| GENERIC_WRITE` | `O_RDWR` | `O_RDWR` |
        /// | none | `0` | `O_RDONLY` | `O_PATH` |
        public enum AccessMode: Sendable {
            case readOnly
            /// Write-only access
            case writeOnly
            /// Read-write access
            case readWrite
            /// Minimum access
            case none
        }

        /// The native flags for creating files on each platform
        public struct NativeCreationFlag: RawRepresentable, Sendable {

            public var rawValue: FlagType
            public init(rawValue: FlagType) {
                self.rawValue = rawValue
            }

            public static var windows: Windows.Type { Windows.self }
            public static var posix: Posix.Type { Posix.self }

            public enum Posix {
                #if !canImport(WinSDK)
                /// Create a file if it does not exist, and open it if it exists.
                /// 
                /// Mapped to `O_CREAT`.
                public static var create: NativeCreationFlag { .init(rawValue: O_CREAT) }
                /// Create a file if it does not exist, and fail if it exists.
                /// 
                /// Mapped to `O_EXCL | O_CREAT`.
                public static var exclusiveCreate: NativeCreationFlag { .init(rawValue: O_EXCL | O_CREAT) }
                #else
                /// Create a file if it does not exist, and open it if it exists.
                @available(*, unavailable, message: "Not available on Windows")
                public static var create: NativeCreationFlag { fatalError() }
                /// Create a file if it does not exist, and fail if it exists.
                @available(*, unavailable, message: "Not available on Windows")
                public static var exclusiveCreate: NativeCreationFlag { fatalError() }
                #endif
            }

            public enum Windows {
                #if canImport(WinSDK)
                /// Open an existing file. Fails if the file does not exist.
                /// 
                /// Mapped to `OPEN_EXISTING`.
                public static var openExisting: NativeCreationFlag { .init(rawValue: DWORD(OPEN_EXISTING)) }
                /// Open an existing file and truncate it to zero length. Fails if the file does not exist.
                /// 
                /// Mapped to `TRUNCATE_EXISTING`.
                public static var truncateExisting: NativeCreationFlag { .init(rawValue: DWORD(TRUNCATE_EXISTING)) }
                /// Open a file if it exists, or create a new file if it does not exist.
                /// 
                /// Mapped to `OPEN_ALWAYS`.
                public static var openAlways: NativeCreationFlag { .init(rawValue: DWORD(OPEN_ALWAYS)) }
                /// Create a new file, always. If the file exists, it will be overwritten.
                /// 
                /// Mapped to `CREATE_ALWAYS`.
                public static var createAlways: NativeCreationFlag { .init(rawValue: DWORD(CREATE_ALWAYS)) }
                /// Create a new file, always. If the file exists, the operation will fail.
                /// 
                /// Mapped to `CREATE_NEW`.
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


        /// The native flags for opening files on each platform
        public struct NativeOpenFlag: OptionSet, Sendable {

            public var rawValue: FlagType
            public init(rawValue: FlagType) {
                self.rawValue = rawValue
            }

            public static var windows: Windows.Type { Windows.self }
            public static var posix: Posix.Type { Posix.self }

            public enum Posix {
                #if !canImport(WinSDK)
                /// Truncate the file to zero length after opening it.
                /// 
                /// Mapped to `O_TRUNC`.
                public static var truncate: NativeOpenFlag { .init(rawValue: O_TRUNC) }
                /// Write operations will append to the end of the file.
                /// 
                /// Mapped to `O_APPEND`.
                public static var append: NativeOpenFlag { .init(rawValue: O_APPEND) }
                /// Forbid symbolic links at the final path component.
                /// 
                /// Mapped to `O_NOFOLLOW`.
                public static var noFollow: NativeOpenFlag { .init(rawValue: O_NOFOLLOW) }
                /// Close the file descriptor on `exec` calls.
                /// 
                /// Mapped to `O_CLOEXEC`.
                public static var closeOnExec: NativeOpenFlag { .init(rawValue: O_CLOEXEC) }
                /// Open the file in non-blocking mode.
                /// 
                /// Mapped to `O_NONBLOCK`.
                public static var nonBlocking: NativeOpenFlag { .init(rawValue: O_NONBLOCK) }
                /// Do not assign a controlling terminal to the opened file.
                /// 
                /// Mapped to `O_NOCTTY`.
                public static var noCtty: NativeOpenFlag { .init(rawValue: O_NOCTTY) }
                /// Expect the opened file to be a directory. If it is not, the open will fail.
                /// 
                /// Mapped to `O_DIRECTORY`.
                public static var directory: NativeOpenFlag { .init(rawValue: O_DIRECTORY) }
                #else
                /// Truncate the file to zero length after opening it.
                public static var truncate: NativeOpenFlag { .init(rawValue: 0) }
                /// Write operations will append to the end of the file.
                public static var append: NativeOpenFlag { .init(rawValue: 0) }
                /// Forbid symbolic links at the final path component.
                public static var noFollow: NativeOpenFlag { .init(rawValue: 0) }
                /// Close the file descriptor on `exec` calls.
                public static var closeOnExec: NativeOpenFlag { .init(rawValue: 0) }
                /// Open the file in non-blocking mode.
                public static var nonBlocking: NativeOpenFlag { .init(rawValue: 0) }
                /// Do not assign a controlling terminal to the opened file.
                public static var noCtty: NativeOpenFlag { .init(rawValue: 0) }
                /// Expect the opened file to be a directory. If it is not, the open will fail.
                public static var directory: NativeOpenFlag { .init(rawValue: 0) }
                #endif
            }

            public enum Windows {
                #if canImport(WinSDK)
                /// Open the reparse point itself, rather than the target of the reparse point.
                /// 
                /// Mapped to `FILE_FLAG_OPEN_REPARSE_POINT`.
                public static var openReparsePoint: NativeOpenFlag { .init(rawValue: DWORD(FILE_FLAG_OPEN_REPARSE_POINT)) }
                /// Enable overlapped I/O on the opened file.
                /// 
                /// Mapped to `FILE_FLAG_OVERLAPPED`.
                public static var overlappedIO: NativeOpenFlag { .init(rawValue: DWORD(FILE_FLAG_OVERLAPPED)) }
                /// Open the file with backup semantics, allowing access to directories and other special files.
                /// 
                /// Mapped to `FILE_FLAG_BACKUP_SEMANTICS`.
                public static var backupSemantics: NativeOpenFlag { .init(rawValue: DWORD(FILE_FLAG_BACKUP_SEMANTICS)) }
                #else
                /// Open the reparse point itself, rather than the target of the reparse point.
                public static var openReparsePoint: NativeOpenFlag { .init(rawValue: 0) }
                /// Enable overlapped I/O on the opened file.
                public static var overlappedIO: NativeOpenFlag { .init(rawValue: 0) }
                /// Open the file with backup semantics, allowing access to directories and other special files.
                public static var backupSemantics: NativeOpenFlag { .init(rawValue: 0) }
                #endif
            }

        }


        /// The native flags for sharing opened files on Windows
        /// 
        /// - Note: This is only applicable on Windows.
        public struct WindowsNativeShareMode: OptionSet, Sendable {

            public var rawValue: FlagType
            public init(rawValue: FlagType) {
                self.rawValue = rawValue
            }

            #if canImport(WinSDK)
            /// Allow other processes to read the opened file.
            /// 
            /// Mapped to `FILE_SHARE_READ`.
            public static var read: WindowsNativeShareMode { .init(rawValue: DWORD(FILE_SHARE_READ)) }
            /// Allow other processes to write to the opened file.
            /// 
            /// Mapped to `FILE_SHARE_WRITE`.
            public static var write: WindowsNativeShareMode { .init(rawValue: DWORD(FILE_SHARE_WRITE)) }
            /// Allow other processes to delete the opened file.
            /// 
            /// Mapped to `FILE_SHARE_DELETE`.
            public static var delete: WindowsNativeShareMode { .init(rawValue: DWORD(FILE_SHARE_DELETE)) }
            #else
            /// Allow other processes to read the opened file.
            public static var read: WindowsNativeShareMode { .init(rawValue: 0) }
            /// Allow other processes to write to the opened file.
            public static var write: WindowsNativeShareMode { .init(rawValue: 0) }
            /// Allow other processes to delete the opened file.
            public static var delete: WindowsNativeShareMode { .init(rawValue: 0) }
            #endif

        }


        /// A type holding additionally inserted or removed native flags
        public struct NativeFlagDiff<NativeFlagType: OptionSet>: Sendable where NativeFlagType.RawValue == FlagType {

            /// The raw flags that are additionally inserted
            public private(set) var inserted: FlagType = 0
            /// The raw flags that are removed
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

            /// Insert additional native flags
            public static func inserted(_ flags: NativeFlagType) -> NativeFlagDiff {
                return .init(inserted: flags)
            }

            /// Remove the native flags
            public static func removed(_ flags: NativeFlagType) -> NativeFlagDiff {
                return .init(removed: flags)
            }

            func apply(to flags: FlagType, mask: FlagType) -> FlagType {
                return (flags | (inserted & mask)) & ~(removed & mask)
            }

            /// Insert additional native flags
            public mutating func insert(_ flags: FlagType) {
                inserted |= flags
                removed ^= (removed & flags)
            }

            /// Remove the native flags
            public mutating func remove(_ flags: FlagType) {
                inserted ^= (inserted & flags)
                removed |= flags
            }

            /// Insert additional native flags
            public mutating func insert(_ flags: NativeFlagType) {
                self.insert(flags.rawValue)
            }

            /// Remove the native flags
            public mutating func remove(_ flags: NativeFlagType) {
                self.remove(flags.rawValue)
            }

        }


        /// The access mode for opening the file handle
        public var access: AccessMode
        /// The creation options when opening the file handle
        public var creation: FileOperationOptions.CreateFile
        /// Whether to truncate the file to zero length after opening it
        public var truncate: Bool
        /// Whether to open the file in append mode, where write operations will 
        /// always append to the end of the file
        public var append: Bool 
        /// Whether a symbolic link at the final path component is resolved.
        ///
        /// If `true` (the default), the link is resolved and its target is opened. 
        /// 
        /// If `false` the link is never resolved and will never open the target. The open will try to open a
        /// handle to the link itself if the platform supports that, otherwise it will fail.
        /// 
        /// In otherwords, this is the `lstat`-style semantic rather than POSIX `O_NOFOLLOW`, and the derived 
        /// flag differs per platform:
        ///
        /// | Platform | Derived flag | Opening a symlink yields |
        /// | -- | -- | -- |
        /// | Windows | `FILE_FLAG_OPEN_REPARSE_POINT` | a handle to the link itself |
        /// | Darwin | `O_SYMLINK` | a handle to the link itself, with any access mode |
        /// | Linux | `O_NOFOLLOW` | a handle to the link itself only with `access == .none` (`O_PATH`); a data-access open fails with `ELOOP` |
        /// | OpenBSD (no `O_PATH`) | `O_NOFOLLOW` | always fails with `ELOOP` |
        ///
        /// A regular file opens the same way with either value. 
        /// 
        /// > Note: 
        /// > To reject symlinks completely (POSIX `O_NOFOLLOW` semantics), insert `.posix.noFollow` 
        /// > through ``platformOpenFlagsDiff``. 
        /// >
        /// > Windows has no native equivalent, so callers open the link itself and check the type on the returned handle.
        public var followSymlink: Bool
        /// Whether to close the file handle when executing a new program
        public var closeOnExec: Bool

        /// The platform-specific native creation flags to override the semantic ones
        public var platformCreationFlagsOverride: NativeCreationFlag?
        /// The platform-specific native open flags used for altering the semantic ones
        public var platformOpenFlagsDiff: NativeFlagDiff<NativeOpenFlag>

        /// Additional access requested on Windows, which is combined with the access mode option
        public var windowsExtraAccess: WindowsAccessMask
        /// The Windows native flags for sharing the opened file
        public var windowsShareMode: WindowsNativeShareMode

        public init(
            access: AccessMode = .readOnly,
            creation: FileOperationOptions.CreateFile = .never,
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


        /// The derived native access mode flags for opening file handles on the current platform
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

        /// The derived native creation flags for opening file handles on the current platform
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

        /// The derived native open flags for opening file handles on the current platform
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
        /// The derived security attributes for opening file handles on Windows
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
