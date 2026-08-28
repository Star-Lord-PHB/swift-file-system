import SystemPackage
import FileSystemCore



public protocol FileHandleProtocol: ~Copyable, ~Escapable {

    var path: FilePath { get }

}



public protocol SystemHandleSupportedFileHandleProtocol: ~Copyable, ~Escapable {
    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R
}



extension FileHandleProtocol where Self: ~Copyable & ~Escapable, Self: SystemHandleSupportedFileHandleProtocol {

    public func fileInfo() throws(PlatformError) -> FileInfo {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.fileInfo()
            }
        }
    }


    public func type() throws(PlatformError) -> FileKind {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try self.withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.type()
            }
        }
    }


    public func fileTimes() throws(PlatformError) -> FileTimes {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.fileTimes()
            }
        }
    }


    public func setFileTimes(
        access: FileTimeSpec? = nil, 
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) throws(PlatformError) {
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.setFileTimes(access: access, modification: modification, creation: creation)
            }
        }
    }


    public func fileAttributes() throws(PlatformError) -> PlatformFileAttributes {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.fileAttributes()
            }
        }
    }


    public func setFileAttributes(_ attributes: PlatformFileAttributes) throws(PlatformError) {
        #if canImport(Glibc) || canImport(Musl)
        try self.setInodeFlags(InternalFS.fileAttributesToInodeFlags(attributes))
        #else 
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.setFileAttributes(attributes)
            }
        }
        #endif
    }


    #if canImport(Glibc) || canImport(Musl)
    public func inodeFlags() throws(PlatformError) -> LinuxInodeFlags {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.fileInodeFlags()
            }
        }
    }


    public func setInodeFlags(_ flags: LinuxInodeFlags) throws(PlatformError) {
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.setFileInodeFlags(flags)
            }
        }
    }
    #endif


    #if canImport(WinSDK)
    public func securityInfo(
        _ members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl
    ) throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor {
        return try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.securityInfo(members)
            }
        }
    }


    public func setSecurityInfo(
        dacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange, 
        sacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange, 
        owner: PlatformIdentity? = nil, 
        group: PlatformIdentity? = nil
    ) throws(PlatformError) {
        
        var members = [] as FileOperationOptions.WindowsSecurityInfoMembers

        switch dacl {
            case .noChange: break
            default:        members.insert(.dacl)
        }
        switch sacl {
            case .noChange: break
            default:        members.insert(.sacl)
        }
        if owner != nil { members.insert(.owner) }
        if group != nil { members.insert(.group) }

        guard !members.isEmpty else { return }

        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in  
                try sysHandle.setSecurityInfo(
                    members, 
                    dacl: dacl.aclView, 
                    sacl: sacl.aclView, 
                    owner: owner?.rawId, 
                    group: group?.rawId
                )
            }
        }

    }
    #else
    public func posixPermissions() throws(PlatformError) -> FilePermissions {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.posixPermissions()
            }
        }
    }
    
    public func setPosixPermissions(_ permissions: FilePermissions) throws(PlatformError) {
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in 
                try sysHandle.setPosixPermissions(permissions)
            }
        }
    }
    #endif
    
    
    public func owner() throws(PlatformError) -> (owner: PlatformIdentity?, group: PlatformIdentity?) {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in
                try sysHandle.owner()
            }
        }
    }


    public func setOwner(owner: PlatformIdentity?, group: PlatformIdentity?) throws(PlatformError) {
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try withUnsafeSystemHandle { (sysHandle) throws(LowLevelError) in
                try sysHandle.fchown(owner: owner, group: group)
            }
        }
    }

}



public protocol SeekableFileHandleProtocol: ~Copyable, ~Escapable, FileHandleProtocol {

    @discardableResult
    func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64

}



extension SeekableFileHandleProtocol where Self: ~Copyable & ~Escapable {

    public var currentOffset: Int64 {
        get throws(PlatformError) {
            do {
                return try seek(to: 0, relativeTo: .current)
            } catch {
                throw .init(cause: error.cause, operation: .readHandleOffset(originalPath: path))
            }
        }
    }


    func trySeek(from offset: Int64, by amount: Int64, operation: @autoclosure () -> PlatformError.Operation) throws(PlatformError) -> Int64 {
        let (result, overflow) = offset.addingReportingOverflow(amount)
        if overflow {
            throw .init(lowLevelError: .init(kind: .arithmeticOverflow), operation: operation())
        } else if result < 0 {
            throw .init(lowLevelError: .init(kind: .invalidInput), operation: operation())
        }
        return result
    }

}



extension SeekableFileHandleProtocol where Self: ~Copyable & ~Escapable & SystemHandleSupportedFileHandleProtocol {

    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64 {
        return try catchLowLevelError(operation: .seekHandle(originalPath: path)) { () throws(LowLevelError) in
            try self.withUnsafeSystemHandle { handle throws(LowLevelError) in
                try handle.seek(to: offset, from: whence)
            }
        }
    }


    public var currentOffset: Int64 {
        get throws(PlatformError) {
            try catchLowLevelError(operation: .readHandleOffset(originalPath: path)) { () throws(LowLevelError) in
                try self.withUnsafeSystemHandle { handle throws(LowLevelError) in
                    try handle.tell()
                }
            }
        }
    }

}
