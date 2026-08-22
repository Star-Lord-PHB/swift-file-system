import struct SystemPackage.FilePath
import struct SystemPackage.FilePermissions
import PlatformCLib


public enum FileOperationOptions {

    public enum CreateFile {
        case never
        case createIfMissing
        case assertMissing
    }


    public struct OpenForReading {

        public var noFollow: Bool
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }

    }


    public struct OpenForDirectory {

        public var noFollow: Bool
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }

    }


    public struct OpenForWriting {

        public var createFile: CreateFile
        public var truncate: Bool 
        public var noFollow: Bool
        public var closeOnExec: Bool

        public init(
            createFile: CreateFile = .never, 
            truncate: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true
        ) {
            self.createFile = createFile
            self.truncate = truncate
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }


        public static func newFile(
            replaceExisting: Bool = true, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true
        ) -> OpenForWriting {
            if replaceExisting {
                .init(createFile: .createIfMissing, truncate: true, noFollow: noFollow, closeOnExec: closeOnExec)
            } else {
                .init(createFile: .assertMissing, truncate: false, noFollow: noFollow, closeOnExec: closeOnExec)
            }
        }


        public static func editFile(
            createIfMissing: Bool = true, 
            truncate: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true
        ) -> OpenForWriting {
            .init(
                createFile: createIfMissing ? .createIfMissing : .never, 
                truncate: truncate, 
                noFollow: noFollow, 
                closeOnExec: closeOnExec
            )
        }

    }


    public enum CopyItemSymlinkOption: Sendable, Equatable, Hashable {
        case copyLink
        case copyTarget
    }


    public enum CopyTargetExistOption: Sendable, Equatable, Hashable {
        case error
        case overwrite
        case skip
    }


    public struct CopyItemOptions: Sendable, Equatable, Hashable {

        public var existingTarget: CopyTargetExistOption
        public var symlinkOption: CopyItemSymlinkOption

        public var preserveSrcAccessTime: Bool

        public var windowsPreserveExactDacl: Bool

        public init(
            existingTarget: CopyTargetExistOption = .overwrite, 
            symlinkOption: CopyItemSymlinkOption = .copyLink, 
            preserveSrcAccessTime: Bool = false, 
            windowsPreserveExactDacl: Bool = false
        ) {
            self.existingTarget = existingTarget
            self.symlinkOption = symlinkOption
            self.preserveSrcAccessTime = preserveSrcAccessTime
            self.windowsPreserveExactDacl = windowsPreserveExactDacl
        }

    }


    public struct DirectoryTraversalOption: OptionSet, Sendable {
        public let rawValue: Int32
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        public static let includeDotEntries: DirectoryTraversalOption = .init(rawValue: 1 << 0)
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
    
    
    public struct FileAccessMode: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }
        public static let read: FileAccessMode = .init(rawValue: 1 << 0)
        public static let write: FileAccessMode = .init(rawValue: 1 << 1)
        public static let execute: FileAccessMode = .init(rawValue: 1 << 2)
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
        public static var allExceptSacl: Self { [.owner, .group, .dacl] }
    }

    public enum WindowsAclUpdateRequest: ~Escapable {
        case replace(WindowsRawAcl.View)
        case remove
        case noChange

        @_lifetime(borrow acl)
        public static func replace(_ acl: borrowing WindowsRawAcl) -> Self {
            .replace(acl.view)
        }

        @_lifetime(copy acl)
        public static func replace(_ acl: WindowsRawAclStateView) -> Self {
            switch acl {
                case .acl(let view, _):  .replace(view)
                case .absent, .null:     .remove
            }
        }

        package var aclView: WindowsRawAcl.View? {
            @_lifetime(copy self)
            get {
                switch consume self {
                    case .replace(let acl): acl
                    case .remove:           nil
                    case .noChange:         nil
                }
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
