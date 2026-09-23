import struct SystemPackage.FilePath
import struct SystemPackage.FilePermissions
import PlatformCLib


/// A namespace for options used in file system operations.
public enum FileOperationOptions {

    /// Options for creating a file when opening a handle for writing 
    public enum CreateFile: Sendable {
        /// Never create a file. Open existing and fail if not exist.
        case never
        /// Create a file if it does not exist, and open it if it exists.
        case createIfMissing
        /// Create a file if it does not exist, and fail if it exists.
        case assertMissing
    }


    /// Options for opening a file handle for reading
    public struct OpenForReading: Sendable {

        /// Whether to forbid symbolic links as the final path component.
        /// 
        /// If `true`, the open will fail if the final path component is a symbolic link. 
        /// Otherwise, the open will follow the symbolic link to its target.
        public var noFollow: Bool
        /// Whether the opened file handle should be automatically closed in the forked child process
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }

    }


    /// Options for opening a file handle for streaming style operations
    public struct OpenForStreaming: Sendable {

        /// Whether to forbid symbolic links as the final path component.
        /// 
        /// If `true`, the open will fail if the final path component is a symbolic link. 
        /// Otherwise, the open will follow the symbolic link to its target.
        public var noFollow: Bool
        /// Whether the opened file handle should be automatically closed in the forked child process
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }

    }


    /// Options for opening a file handle to a directory
    public struct OpenForDirectory: Sendable {

        /// Whether to forbid symbolic links as the final path component.
        /// 
        /// If `true`, the open will fail if the final path component is a symbolic link. 
        /// Otherwise, the open will follow the symbolic link to its target.
        public var noFollow: Bool
        /// Whether the opened file handle should be automatically closed in the forked child process
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }

    }


    /// Options for opening a file handle for writing`
    public struct OpenForWriting: Sendable {

        /// Options for file creation
        public var createFile: CreateFile
        /// Whether to truncate the file contents after opening it
        public var truncate: Bool 
        /// Whether to forbid symbolic links as the final path component.
        /// 
        /// If `true`, the open will fail if the final path component is a symbolic link. 
        /// Otherwise, the open will follow the symbolic link to its target.
        public var noFollow: Bool
        /// Whether the opened file handle should be automatically closed in the forked child process
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


        
        /// Option builder for creating a new file for writing
        /// 
        /// - Parameter replaceExisting: If `true`, exising file will be truncated. 
        ///                              If `false`, the open will fail if the file already exists.
        /// - Parameter noFollow: If `true`, the open will fail if the final path component is a symbolic link. 
        ///                       If `false`, the open will follow the symbolic link to its target
        /// - Parameter closeOnExec: Whether the opened file handle should be automatically closed in the forked child process
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

        
        /// Option builder for editing an existing file
        /// - Parameters:
        ///   - createIfMissing: If `true`, the file will be created if it does not exist. 
        ///                      If `false`, the open will fail if the file does not exist.
        ///   - truncate: If `true`, the file will be truncated after opening it.
        ///               If `false`, the file will be opened without truncation.
        ///   - noFollow: If `true`, the open will fail if the final path component is a symbolic link.
        ///               If `false`, the open will follow the symbolic link to its target.
        ///   - closeOnExec: Whether the opened file handle should be automatically closed in the forked child process
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


    /// Options for handling symbolic links during file copy
    public enum CopyItemSymlinkOption: Sendable, Equatable, Hashable {
        /// Copy the symbolic link itself
        case copyLink
        /// Copy the target of the symbolic link
        case copyTarget
    }


    /// Options for handling existing target during file copy
    public enum CopyTargetExistOption: Sendable, Equatable, Hashable {
        /// Fail the copy operation if the target already exists
        case error
        /// Overwrite the existing target if it exists
        case overwrite
        /// Skip the copy operation if the target already exists
        case skip
    }


    /// Options for copying a file or directory
    public struct CopyItemOptions: Sendable, Equatable, Hashable {

        /// The behavior when the target already exists
        public var existingTarget: CopyTargetExistOption
        /// The behavior for handling the root symbolic links during the copy operation
        /// 
        /// - Note:
        ///   This option applies only to the root symbolic link in an recursive copy operation.
        ///   Links encountered when copying the children of a directory will not be affected
        public var symlinkOption: CopyItemSymlinkOption

        /// Whether to preserve the access time of the source file when copying 
        /// 
        /// - Attention:
        ///   On Linux, trying to restore the access time of a file cause the change time to be updated.
        public var preserveSrcAccessTime: Bool

        /// Whether to preserve the exact DACL of the source file when copying on Windows
        /// 
        /// If set to `true`, the copied file at the destination will have exactly the same DACL as the source file
        /// without being affected by the inherited ACEs from the parent directory. Inherited ACEs at the source 
        /// file will also be copied.
        /// 
        /// If set to `false`, only the non-inherited ACEs of the source file will be copied to the destination, and 
        /// the destination file will also inherit ACEs from its own parent directory. 
        /// 
        /// - Note: This option is only applicable on Windows
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


    /// Options for traversing a directory
    public struct DirectoryTraversalOption: OptionSet, Sendable {
        public let rawValue: Int32
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        /// Whether to include the `.` and `..` entries in the traversal results
        public static let includeDotEntries: DirectoryTraversalOption = .init(rawValue: 1 << 0)
        // TODO: Add more options if needed
    }


    /// Options for seeking within a file
    public enum SeekWhence: CInt {

        /// Seek relative to the beginning of the file
        case beginning
        /// Seek relative to the current position in the file
        case current
        /// Seek relative to the end of the file
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
    
    
    /// Generic file access modes
    public struct FileAccessMode: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }
        /// Access mode for reading
        public static let read: FileAccessMode = .init(rawValue: 1 << 0)
        /// Access mode for writing
        public static let write: FileAccessMode = .init(rawValue: 1 << 1)
        /// Access mode for executing
        public static let execute: FileAccessMode = .init(rawValue: 1 << 2)
    }


    /// Options of access permissions for accessing metadata from a file handle
    /// 
    /// - Note: This option is currently only useful on Windows
    public struct MetadataHandleAccess: OptionSet, Sendable {
        public let accessMask: WindowsAccessMask
        public var rawValue: WindowsAccessMask.RawValue {
            accessMask.rawValue
        }
        public init(rawValue: WindowsAccessMask.RawValue) {
            self.accessMask = .init(rawValue: rawValue)
        }
        init(accessMask: WindowsAccessMask) {
            self.accessMask = accessMask
        }
        public enum Windows {
            /// Access mode for reading file attributes
            public static var readAttributes: MetadataHandleAccess { .init(accessMask: .readAttributes) }
            /// Access mode for reading file security descriptor
            public static var readControl: MetadataHandleAccess { .init(accessMask: .readControl) }
            /// Access mode for writing file attributes
            public static var writeAttributes: MetadataHandleAccess { .init(accessMask: .writeAttributes) }
            /// Access mode for writing file security descriptor
            public static var writeDAC: MetadataHandleAccess { .init(accessMask: .writeDAC) }
            /// Access mode for writing file owner
            public static var writeOwner: MetadataHandleAccess { .init(accessMask: .writeOwner) }
            /// Access mode for reading and writing SACL
            public static var accessSystemSecurity: MetadataHandleAccess { .init(accessMask: .accessSystemSecurity) }
        }
        /// Option namespace for Windows
        public static var windows: Windows.Type { Windows.self }
    }


    #if canImport(WinSDK)
    /// Members of a Windows security descriptor
    public struct WindowsSecurityInfoMembers: Sendable, OptionSet {
        public let rawValue: DWORD
        public init(rawValue: DWORD) {
            self.rawValue = rawValue
        }
        /// Owner of the file
        public static let owner: Self = .init(rawValue: .init(OWNER_SECURITY_INFORMATION))
        /// Group of the file
        public static let group: Self = .init(rawValue: .init(GROUP_SECURITY_INFORMATION))
        /// DACL of the file
        public static let dacl: Self = .init(rawValue: .init(DACL_SECURITY_INFORMATION))
        /// SACL of the file
        public static let sacl: Self = .init(rawValue: .init(SACL_SECURITY_INFORMATION))
        /// All members of the security descriptor
        public static var all: Self { [.owner, .group, .dacl, .sacl] }
        /// All members of the security descriptor excluding SACL
        public static var allExceptSacl: Self { [.owner, .group, .dacl] }
    }

    /// Options for updating the DACL / SACL of a file on Windows
    public enum WindowsAclUpdateRequest: ~Escapable, Sendable {
        /// Replace the existing DACL / SACL with the provided one
        case replace(WindowsRawAcl.View)
        /// Remove the existing DACL / SACL (i.e.: make it NULL ACL)
        case remove
        /// Do not change the existing DACL / SACL
        case noChange

        /// Replace the existing DACL / SACL with the provided one
        @_lifetime(borrow acl)
        public static func replace(_ acl: borrowing WindowsRawAcl) -> Self {
            .replace(acl.view)
        }

        /// Replace the existing DACL / SACL with the provided one
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
    /// Options for Poll events to monitored on a noblocking file handle
    public struct PosixPollEventToMonitor: OptionSet, Sendable {

        public let rawValue: Int16

        public init(rawValue: Int16) {
            self.rawValue = rawValue
        }

        /// Monitor for read events
        public static let read: PosixPollEventToMonitor = .init(rawValue: Int16(POLLIN))
        /// Monitor for write events
        public static let write: PosixPollEventToMonitor = .init(rawValue: Int16(POLLOUT))
        /// Monitor for both read and write events
        public static let readWrite: PosixPollEventToMonitor = [.read, .write]

    }
    #endif 

}
