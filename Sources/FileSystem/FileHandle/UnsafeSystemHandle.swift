import SystemPackage
import Foundation

#if canImport(WinSDK)
import WinSDK
#endif



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


    func unownedHandle() -> UnsafeUnownedSystemHandle {
        return .init(unsafeRawHandle: unsafeRawHandle)
    }


    public consuming func close() throws(SystemError) {
        let handle = self.unsafeRawHandle
        discard self
        try Self._close(handle)
    }


    private static func _close(_ handle: SystemHandleType) throws(SystemError) {

        #if canImport(WinSDK)
        try execThrowingCFunction {
            CloseHandle(handle)
        }
        #else 
        try execThrowingCFunction {
            Foundation.close(handle)
        }
        #endif

    }

}


struct UnsafeUnownedSystemHandle {

    #if canImport(WinSDK)
    public typealias SystemHandleType = WinSDK.HANDLE
    #else 
    public typealias SystemHandleType = CInt
    #endif

    let unsafeRawHandle: SystemHandleType

}



extension UnsafeSystemHandle {

    public struct OpenOptions {

        #if canImport(WinSDK)
        public typealias FlagType = DWORD
        #else
        public typealias FlagType = CInt
        #endif

        public enum CreationOptions {
            case never
            case createIfMissing 
            case assertMissing
        }


        public enum AccessMode {
            case readOnly(metadataOnly: Bool = false)
            case writeOnly
            case readWrite
        }

        public var access: AccessMode
        public var creation: CreationOptions
        public var truncate: Bool
        public var append: Bool 
        public var noFollow: Bool 
        public var closeOnExec: Bool
        public var noBlocking: Bool 
        public var platformAdditionalFlags: FlagType

        public var accessModeFlags: FlagType {

            #if canImport(WinSDK)

            return switch access {
                case .readOnly(metadataOnly: true):    FlagType(FILE_READ_ATTRIBUTES | READ_CONTROL)
                case .readOnly:                        FlagType(GENERIC_READ)
                case .writeOnly where append:          FlagType(FILE_APPEND_DATA)
                case .writeOnly:                       FlagType(GENERIC_WRITE)
                case .readWrite where append:          FlagType(GENERIC_READ | FILE_APPEND_DATA)
                case .readWrite:                       FlagType(GENERIC_READ | GENERIC_WRITE)
            }

            #else

            return switch access {
                #if !(canImport(Darwin) || os(FreeBSD) || os(OpenBSD))      // O_PATH is not available on BSD or macOS
                case .readOnly(metadataOnly: true): FlagType(O_RDONLY | __O_PATH)
                #endif
                case .readOnly:                     FlagType(O_RDONLY)
                case .writeOnly:                    FlagType(O_WRONLY)
                case .readWrite:                    FlagType(O_RDWR)
            }

            #endif

        }

        public var creationFlags: FlagType {

            #if canImport(WinSDK)

            return switch (creation, truncate) {
                case (.never, false):           FlagType(OPEN_EXISTING)
                case (.never, true):            FlagType(TRUNCATE_EXISTING)
                case (.createIfMissing, false): FlagType(OPEN_ALWAYS)
                case (.createIfMissing, true):  FlagType(CREATE_ALWAYS)
                case (.assertMissing, _):       FlagType(CREATE_NEW)
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

            flags |= FlagType(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS)
            if noFollow { flags |= FlagType(FILE_FLAG_OPEN_REPARSE_POINT) }
            if noBlocking { flags |= FlagType(FILE_FLAG_OVERLAPPED) }

            #else 

            if truncate { flags |= O_TRUNC }
            if append { flags |= O_APPEND }
            if noFollow { flags |= O_NOFOLLOW }
            if closeOnExec { flags |= O_CLOEXEC }
            if noBlocking { flags |= O_NONBLOCK }

            #endif 

            return flags | platformAdditionalFlags

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
            platformAdditionalFlags: FlagType = 0
        ) {
            self.access = access
            self.creation = creation
            self.truncate = truncate
            self.append = append
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
            self.noBlocking = noBlocking
            self.platformAdditionalFlags = platformAdditionalFlags
        }
        
    }



    public enum SeekWhence: CInt {

        case beginning
        case current
        case end

        public var rawValue: CInt {
            #if canImport(WinSDK)
            switch self {
                case .beginning: WinSDK.FILE_BEGIN
                case .current: WinSDK.FILE_CURRENT
                case .end: WinSDK.FILE_END
            }
            #else 
            switch self {
                case .beginning: SEEK_SET
                case .current: SEEK_CUR
                case .end: SEEK_END
            }
            #endif
        }

        public init?(rawValue: CInt) {
            #if canImport(WinSDK)
            switch rawValue {
                case WinSDK.FILE_BEGIN: self = .beginning
                case WinSDK.FILE_CURRENT: self = .current
                case WinSDK.FILE_END: self = .end
                default: return nil
            }
            #else 
            switch rawValue {
                case SEEK_SET: self = .beginning
                case SEEK_CUR: self = .current
                case SEEK_END: self = .end
                default: return nil
            }
            #endif
        }
        
    }

}