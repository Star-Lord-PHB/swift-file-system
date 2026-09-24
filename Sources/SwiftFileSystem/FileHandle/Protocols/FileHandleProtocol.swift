import SystemPackage
import FileSystemCore



public protocol FileHandleProtocol: ~Copyable, ~Escapable {

    var path: FilePath { get }

}



public protocol SystemHandleSupportedFileHandleProtocol: ~Copyable, ~Escapable {

    var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get 
    }

}



extension SystemHandleSupportedFileHandleProtocol where Self: ~Copyable & ~Escapable {

    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ body: (borrowing UnsafeSystemHandle) throws(E) -> R
    ) throws(E) -> R {
        try unsafeHandleContext.withUnsafeSystemHandle(body)
    }

}



extension FileHandleProtocol where Self: ~Copyable & ~Escapable, Self: SystemHandleSupportedFileHandleProtocol {

    func withUnsafeSystemHandle<R: ~Copyable>(
        operation: PlatformError.Operation,
        _ body: (borrowing UnsafeSystemHandle) throws(LowLevelError) -> R
    ) throws(PlatformError) -> R {
        try catchLowLevelError(operation: operation) { () throws(LowLevelError) in
            try withUnsafeSystemHandle(body)
        }
    }


    func withUnsafeSystemHandleForMetadata<R: ~Copyable>(
        requiringAccess metadataAccess: FileOperationOptions.MetadataHandleAccess,
        operation: PlatformError.Operation,
        _ body: (borrowing UnsafeSystemHandle) throws(LowLevelError) -> R
    ) throws(PlatformError) -> R {
        try catchLowLevelError(operation: operation) { () throws(LowLevelError) in
            try unsafeHandleContext.withUnsafeMetadataHandle(requiringAccess: metadataAccess, body)
        }
    }


    public func fileInfo() throws(PlatformError) -> FileInfo {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readAttributes,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.fileInfo()
        }
    }


    public func type() throws(PlatformError) -> FileKind {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readAttributes,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.type()
        }
    }


    public func fileTimes() throws(PlatformError) -> FileTimes {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readAttributes,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.fileTimes()
        }
    }


    public func setFileTimes(
        access: FileTimeSpec? = nil, 
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) throws(PlatformError) {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.writeAttributes,
            operation: .setMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.setFileTimes(access: access, modification: modification, creation: creation)
        }
    }


    public func fileAttributes() throws(PlatformError) -> PlatformFileAttributes {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readAttributes,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.fileAttributes()
        }
    }


    public func setFileAttributes(_ attributes: PlatformFileAttributes) throws(PlatformError) {
        #if os(Linux) || os(Android)
        try self.setInodeFlags(InternalFS.fileAttributesToInodeFlags(attributes))
        #else
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.writeAttributes,
            operation: .setMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.setFileAttributes(attributes)
        }
        #endif
    }


    #if os(Linux) || os(Android)
    public func inodeFlags() throws(PlatformError) -> LinuxInodeFlags {
        try withUnsafeSystemHandle(operation: .fetchMeta(path)) { (handle) throws(LowLevelError) in
            try handle.fileInodeFlags()
        }
    }


    public func setInodeFlags(_ flags: LinuxInodeFlags) throws(PlatformError) {
        try withUnsafeSystemHandle(operation: .setMeta(path)) { (handle) throws(LowLevelError) in
            try handle.setFileInodeFlags(flags)
        }
    }
    #endif


    #if canImport(WinSDK)
    public func securityInfo(
        _ members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl
    ) throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readControl,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.securityInfo(members)
        }
    }


    public func setSecurityInfo(
        dacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange, 
        sacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange, 
        owner: PlatformIdentity? = nil, 
        group: PlatformIdentity? = nil
    ) throws(PlatformError) {
        
        var members = [] as FileOperationOptions.WindowsSecurityInfoMembers
        var access = [.windows.readControl] as FileOperationOptions.MetadataHandleAccess

        switch dacl {
            case .noChange: break
            default:        
                members.insert(.dacl)
                access.insert(.windows.writeDAC)
        }
        switch sacl {
            case .noChange: break
            default:
                members.insert(.sacl)
                access.insert(.windows.accessSystemSecurity)
        }
        if owner != nil { 
            members.insert(.owner) 
            access.insert(.windows.writeOwner)
        }
        if group != nil { 
            members.insert(.group) 
            access.insert(.windows.writeOwner)
        }

        guard !members.isEmpty else { return }

        try withUnsafeSystemHandleForMetadata(
            requiringAccess: access,
            operation: .setMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.setSecurityInfo(members, dacl: dacl.aclView, sacl: sacl.aclView, owner: owner?.rawId, group: group?.rawId)
        }

    }
    #else
    public func posixPermissions() throws(PlatformError) -> FilePermissions {
        try withUnsafeSystemHandle(operation: .fetchMeta(path)) { (handle) throws(LowLevelError) in
            try handle.posixPermissions()
        }
    }
    
    public func setPosixPermissions(_ permissions: FilePermissions) throws(PlatformError) {
        try withUnsafeSystemHandle(operation: .setMeta(path)) { (handle) throws(LowLevelError) in
            try handle.setPosixPermissions(permissions)
        }
    }
    #endif
    
    
    public func owner() throws(PlatformError) -> (owner: PlatformIdentity?, group: PlatformIdentity?) {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readControl,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.owner()
        }
    }


    public func setOwner(owner: PlatformIdentity?, group: PlatformIdentity?) throws(PlatformError) {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.writeOwner,
            operation: .setMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.fchown(owner: owner, group: group)
        }
    }

}



public protocol SeekableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    @discardableResult
    func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64

    var currentOffset: Int64 { get throws(PlatformError) }

}



extension SeekableFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64 {
        return try withUnsafeSystemHandle(operation: .seekHandle(originalPath: path)) { (handle) throws(LowLevelError) in
            try handle.seek(to: offset, from: whence)
        }
    }


    public var currentOffset: Int64 {
        get throws(PlatformError) {
            try withUnsafeSystemHandle(operation: .readHandleOffset(originalPath: path)) { (handle) throws(LowLevelError) in
                try handle.tell()
            }
        }
    }

}
