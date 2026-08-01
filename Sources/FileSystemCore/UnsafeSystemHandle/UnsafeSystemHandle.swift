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
    public mutating func setNonBlocking(_ value: Bool) throws(LowLevelError) {

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

}



extension UnsafeSystemHandle {

    public struct OpenOptions {

        #if canImport(WinSDK)
        public typealias FlagType = DWORD
        #else
        public typealias FlagType = CInt
        #endif

        public struct PlatformSpecificOptions: OptionSet, Sendable {
            public var rawValue: UInt64
            public init(rawValue: UInt64) {
                self.rawValue = rawValue
            }
            public enum Posix {
                public static let directoryOnly: PlatformSpecificOptions = .init(rawValue: 1 << 0)
            }
            public enum Windows {
                public static let backupSemantics: PlatformSpecificOptions = .init(rawValue: 1 << 32)
                package static let delayedTruncate: PlatformSpecificOptions = .init(rawValue: 1 << 33)
            }
            public static var windows: Windows.Type { Windows.self }
            public static var posix: Posix.Type { Posix.self }
        }


        public enum CreationOptions {
            case never
            case createIfMissing 
            case assertMissing
        }


        public enum AccessMode {
            case readOnly(metadataOnly: Bool = false)
            case writeOnly(metadataOnly: Bool = false)
            case readWrite(metadataOnly: Bool = false)
            case none
        }


        public var access: AccessMode
        public var creation: CreationOptions
        public var truncate: Bool
        public var append: Bool 
        public var noFollow: Bool 
        public var closeOnExec: Bool
        public var noBlocking: Bool 

        public var platformSpecificOptions: PlatformSpecificOptions
        public var platformAdditionalRawFlags: FlagType

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
                case .readWrite where append:          GENERIC_READ | FlagType(bitPattern: FILE_APPEND_DATA) | readMetaFlags | writeMetaFlags
                case .readWrite:                       GENERIC_READ | FlagType(bitPattern: GENERIC_WRITE) | readMetaFlags | writeMetaFlags
                case .none:                            0 as FlagType
            }

            if truncate {
                flags |= FlagType(bitPattern: GENERIC_WRITE)
            }

            return flags

            #else

            return switch access {
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
                case .none:                         0
                #endif
            }

            #endif

        }

        public var creationFlags: FlagType {

            #if canImport(WinSDK)

            let truncate = self.truncate && !platformSpecificOptions.contains(.windows.delayedTruncate)

            return switch (creation, truncate) {
                case (.never, false):           FlagType(bitPattern: OPEN_EXISTING)
                case (.never, true):            FlagType(bitPattern: TRUNCATE_EXISTING)
                case (.createIfMissing, false): FlagType(bitPattern: OPEN_ALWAYS)
                case (.createIfMissing, true):  FlagType(bitPattern: CREATE_ALWAYS)
                case (.assertMissing, _):       FlagType(bitPattern: CREATE_NEW)
            }

            #else 

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
            if platformSpecificOptions.contains(.windows.backupSemantics) { flags |= FlagType(bitPattern: FILE_FLAG_BACKUP_SEMANTICS) }

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
            if platformSpecificOptions.contains(.posix.directoryOnly) { flags |= O_DIRECTORY }

            #endif 

            return flags | platformAdditionalRawFlags

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


        public init(
            access: AccessMode = .readOnly(),
            creation: CreationOptions = .never, 
            truncate: Bool = false, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true, 
            noBlocking: Bool = false, 
            platformSpecificOptions: PlatformSpecificOptions = [],
            platformAdditionalRawFlags: FlagType = 0
        ) {
            self.access = access
            self.creation = creation
            self.truncate = truncate
            self.append = append
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
            self.noBlocking = noBlocking
            self.platformSpecificOptions = platformSpecificOptions
            self.platformAdditionalRawFlags = platformAdditionalRawFlags
        }
        
    }

}
