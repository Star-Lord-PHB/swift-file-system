import SystemPackage
import PlatformCLib


public enum FileOperationOptions {

    public enum CreateFile {
        case never
        case createIfMissing(permissions: FilePermissions? = nil)
        case assertMissing(permissions: FilePermissions? = nil)

        var unsafeSystemCreationOptions: UnsafeSystemHandle.OpenOptions.CreationOptions {
            switch self {
                case .never:            .never
                case .createIfMissing:  .createIfMissing
                case .assertMissing:    .assertMissing
            }
        }

        var creationPermissions: FilePermissions? {
            switch self {
                case .never:                            nil
                #if !canImport(WinSDK)
                // On Posix, when creating file is requested but no creation permissions are specified, 
                // use default permissions 0o644 (rw-r--r--).
                // On Windows, permissions will be inherited from parent directory, so no need to provide default permissions.
                case .createIfMissing(.none):           [.ownerReadWrite, .groupRead, .otherRead]
                case .assertMissing(.none):             [.ownerReadWrite, .groupRead, .otherRead]
                #endif
                case .createIfMissing(let permissions): permissions
                case .assertMissing(let permissions):   permissions
            }
        }
    }


    public struct OpenForReading {

        public var noFollow: Bool
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }


        func unsafeSystemFileOpenOptions(
            platformAdditionalRawFlags: UnsafeSystemHandle.OpenOptions.FlagType = 0
        ) -> UnsafeSystemHandle.OpenOptions {
            .init(
                access: .readOnly(), 
                noFollow: noFollow, 
                closeOnExec: closeOnExec, 
                platformAdditionalRawFlags: platformAdditionalRawFlags
            )
        }

    }


    public struct OpenForDirectory {

        public var noFollow: Bool
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }


        func unsafeSystemFileOpenOptions(
            platformAdditionalFlags: UnsafeSystemHandle.OpenOptions.FlagType = 0
        ) -> UnsafeSystemHandle.OpenOptions {
            .init(
                access: .readOnly(), 
                noFollow: noFollow, 
                closeOnExec: closeOnExec, 
                platformSpecificOptions: [.posix.directoryOnly, .windows.backupSemantics],
                platformAdditionalRawFlags: platformAdditionalFlags
            )
        }

    }


    public struct OpenForWriting {

        public var createFile: CreateFile
        public var truncate: Bool 
        public var append: Bool
        public var noFollow: Bool
        public var closeOnExec: Bool

        public var creationPermissions: FilePermissions? {
            createFile.creationPermissions
        }


        public init(
            createFile: CreateFile = .never, 
            truncate: Bool = false, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true
        ) {
            self.createFile = createFile
            self.truncate = truncate
            self.append = append
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }


        func unsafeSystemFileOpenOptions(
            platformAdditionalFlags: UnsafeSystemHandle.OpenOptions.FlagType = 0
        ) -> UnsafeSystemHandle.OpenOptions {
            .init(
                access: .writeOnly(), 
                creation: createFile.unsafeSystemCreationOptions, 
                truncate: truncate, 
                append: append, 
                noFollow: noFollow, 
                closeOnExec: closeOnExec, 
                platformAdditionalRawFlags: platformAdditionalFlags
            )
        }


        public static func newFile(
            replaceExisting: Bool = true, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true,
            creationPermissions: FilePermissions? = nil
        ) -> OpenForWriting {
            if replaceExisting {
                .init(createFile: .createIfMissing(permissions: creationPermissions), truncate: true, append: append, noFollow: noFollow, closeOnExec: closeOnExec)
            } else {
                .init(createFile: .assertMissing(permissions: creationPermissions), truncate: false, append: append, noFollow: noFollow, closeOnExec: closeOnExec)
            }
        }


        public static func editFile(
            createIfMissing: Bool = true, 
            truncate: Bool = false, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true,
            creationPermissions: FilePermissions? = nil
        ) -> OpenForWriting {
            .init(
                createFile: createIfMissing ? .createIfMissing(permissions: creationPermissions) : .never, 
                truncate: truncate, 
                append: append, 
                noFollow: noFollow, 
                closeOnExec: closeOnExec
            )
        }

    }


    public enum CopyItemSymlinkOption {
        case copyLink
        case copyTarget
    }


    public enum CopyTargetExistOption {
        case error
        case overwrite
        case skip
    }


    public struct DirectoryTraversalOption: OptionSet, Sendable {
        public let rawValue: Int32
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        public static let skipDotEntries: DirectoryTraversalOption = .init(rawValue: 1 << 0)
        public static let skipDir: DirectoryTraversalOption = .init(rawValue: 1 << 1)
        // TODO: Add more options if needed
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


    #if canImport(WinSDK)
    public struct WindowsSecurityInfoMembers: Sendable, OptionSet {
        public let rawValue: DWORD
        public init(rawValue: DWORD) {
            self.rawValue = rawValue
        }
        public static let owner: Self = .init(rawValue: .init(OWNER_SECURITY_INFORMATION))
        public static let group: Self = .init(rawValue: .init(GROUP_SECURITY_INFORMATION))
        public static let dacl: Self = .init(rawValue: .init(DACL_SECURITY_INFORMATION))
        public static let sacl: Self = .init(rawValue: .init(SACL_SECURITY_INFORMATION))
        public static var all: Self { [.owner, .group, .dacl, .sacl] }
    }


    public enum WindowsAclUpdateRequest: ~Copyable {
        case replace(WindowsRawAcl)
        case remove
        case noChange

        consuming func takeRawAcl() -> WindowsRawAcl? {
            switch consume self {
                case .replace(let acl): acl
                case .remove:           nil
                case .noChange:         nil
            }
        }
    }
    #else
    public enum PosixPollEventToMonitor: Int16, Sendable {
        case read
        case write
        case readWrite
        public var rawValue: Int16 {
            switch self {
                case .read:         .init(POLLIN)
                case .write:        .init(POLLOUT)
                case .readWrite:    .init(POLLIN | POLLOUT)
            }
        }
        public init?(rawValue: Int16) {
            switch CInt(rawValue) {
                case POLLIN:            self = .read
                case POLLOUT:           self = .write
                case POLLIN | POLLOUT:  self = .readWrite
                default:                return nil
            }
        }
    }
    #endif 

}