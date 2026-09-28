import SystemPackage
import FileSystemCore



/// A protocol for general file handles.
public protocol FileHandleProtocol: ~Copyable, ~Escapable {

    /// The path to the item where this handle is opened.
    var path: FilePath { get }

}



/// A protocol for file handles that can provide an ``UnsafeSystemHandle`` and associated opening context.
public protocol SystemHandleSupportedFileHandleProtocol: ~Copyable, ~Escapable {

    /// Gets an unowned view to the underlying ``UnsafeSystemHandle`` and associated opening context.
    var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get 
    }

}



extension SystemHandleSupportedFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Access the underlying ``UnsafeSystemHandle`` in a closure.
    /// 
    /// - Parameter body: A closure for accessing the underlying ``UnsafeSystemHandle``.
    /// 
    /// - Warning: Do not return or store the ``UnsafeSystemHandle`` outside of the closure.
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


    /// Gets the metadata of the item referred by this handle.
    public func info() throws(PlatformError) -> FileInfo {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readAttributes,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.info()
        }
    }


    /// Gets the type of the item referred by this handle.
    public func type() throws(PlatformError) -> FileKind {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readAttributes,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.type()
        }
    }


    /// Gets the file times of the item referred by this handle.
    /// 
    /// - Last access time
    /// - Last modification time
    /// - Status change time
    /// - Creation time (if supported by the platform)
    public func times() throws(PlatformError) -> FileTimes {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readAttributes,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.times()
        }
    }


    /// Updates the file times of the item referred by this handle.
    /// - Parameters:
    ///   - access: The new last access time, or `nil` to leave unchanged.
    ///   - modification: The new last modification time, or `nil` to leave unchanged
    ///   - creation: The new creation time, or `nil` to leave unchanged.
    /// 
    /// > Attention: 
    /// > The behavior of this method varies across platforms:
    /// > * On Linux, setting the creation time is not supported and will be ignored.
    /// > * On Darwin and BSD, the new creation time cannot be later than the modification time.
    public func setTimes(
        access: FileTimeSpec? = nil, 
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) throws(PlatformError) {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.writeAttributes,
            operation: .setMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.setTimes(access: access, modification: modification, creation: creation)
        }
    }


    /// Gets the file attributes (flags) of the item referred by this handle.
    public func attributes() throws(PlatformError) -> PlatformFileAttributes {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readAttributes,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.attributes()
        }
    }


    /// Updates the file attributes (flags) of the item referred by this handle.
    /// - Parameter attributes: The new file attributes to set.
    public func setAttributes(_ attributes: PlatformFileAttributes) throws(PlatformError) {
        #if os(Linux) || os(Android)
        try self.setInodeFlags(InternalFS.attributesToInodeFlags(attributes))
        #else
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.writeAttributes,
            operation: .setMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.setAttributes(attributes)
        }
        #endif
    }


    #if os(Linux) || os(Android)
    /// Gets the inode flags of the item referred by this handle.
    public func inodeFlags() throws(PlatformError) -> LinuxInodeFlags {
        try withUnsafeSystemHandle(operation: .fetchMeta(path)) { (handle) throws(LowLevelError) in
            try handle.inodeFlags()
        }
    }


    /// Updates the inode flags of the item referred by this handle.
    /// - Parameter flags: The new inode flags to set.
    public func setInodeFlags(_ flags: LinuxInodeFlags) throws(PlatformError) {
        try withUnsafeSystemHandle(operation: .setMeta(path)) { (handle) throws(LowLevelError) in
            try handle.setInodeFlags(flags)
        }
    }
    #endif


    #if canImport(WinSDK)
    /// Gets the Windows security descriptor of the item referred by this handle.
    /// - Parameter members: The members of the security descriptor to retrieve. 
    ///                      Defaults to all members except the SACL.
    public func securityInfo(
        querying members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl
    ) throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor {
        var access = [.windows.readControl] as FileOperationOptions.MetadataHandleAccess
        if members.contains(.sacl) {
            access.insert(.windows.accessSystemSecurity)
        }
        return try withUnsafeSystemHandleForMetadata(
            requiringAccess: access,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.securityInfo(members)
        }
    }


    /// Updates the Windows security descriptor of the item referred by this handle.
    /// - Parameters:
    ///   - dacl: How to update the DACL. 
    ///           Can be replacing with a new DACL, removing it or leaving it unchanged.
    ///   - sacl: How to update the SACL.
    ///          Can be replacing with a new SACL, removing it or leaving it unchanged.
    ///   - owner: The new owner to set, or `nil` to leave unchanged.
    ///   - group: The new group to set, or `nil` to leave unchanged.
    /// 
    /// - Seealso: ``FileOperationOptions/WindowsAclUpdateRequest``
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
    /// Gets the POSIX permissions of the item referred by this handle.
    public func posixPermissions() throws(PlatformError) -> FilePermissions {
        try withUnsafeSystemHandle(operation: .fetchMeta(path)) { (handle) throws(LowLevelError) in
            try handle.posixPermissions()
        }
    }
    
    /// Updates the POSIX permissions of the item referred by this handle.
    /// - Parameter permissions: The new POSIX permissions to set.
    public func setPosixPermissions(_ permissions: FilePermissions) throws(PlatformError) {
        try withUnsafeSystemHandle(operation: .setMeta(path)) { (handle) throws(LowLevelError) in
            try handle.setPosixPermissions(permissions)
        }
    }
    #endif
    
    
    /// Gets the owner and group of the item referred by this handle.
    public func owner() throws(PlatformError) -> (owner: PlatformIdentity, group: PlatformIdentity) {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.readControl,
            operation: .fetchMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.owner()
        }
    }


    /// Updates the owner and group of the item referred by this handle.
    /// - Parameters:
    ///   - owner: The new owner to set, or `nil` to leave unchanged.
    ///   - group: The new group to set, or `nil` to leave unchanged.
    public func setOwner(owner: PlatformIdentity?, group: PlatformIdentity?) throws(PlatformError) {
        try withUnsafeSystemHandleForMetadata(
            requiringAccess: .windows.writeOwner,
            operation: .setMeta(path)
        ) { (handle) throws(LowLevelError) in
            try handle.fchown(owner: owner, group: group)
        }
    }

}



/// A protocol for file handles that support seeking the file pointer.
public protocol SeekableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    /// Seeks the file pointer to a new position.
    /// - Parameters:
    ///   - offset: The offset to seek to.
    ///   - whence: The relative starting point for the offset.
    /// - Returns: The new position of the file pointer after seeking.
    @discardableResult
    func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64

    /// Gets the current position of the file pointer, relative to the beginning of the file.
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
