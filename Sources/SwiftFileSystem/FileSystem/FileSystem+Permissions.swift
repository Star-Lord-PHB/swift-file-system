import SystemPackage
import FileSystemCore


extension FileSystem {
    
    public func canAccess(
        itemAt path: FilePath,
        for accessMode: FileOperationOptions.FileAccessMode = [.read, .write],
        followSymlink: Bool = true
    ) throws(PlatformError) -> Bool {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try InternalFS.canAccess(itemAt: path, for: accessMode, followSymlink: followSymlink)
        }
    }
    
    
    #if canImport(WinSDK)
    
    public func getSecurityInfo(
        forItemAt path: FilePath,
        querying members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl,
        followSymlink: Bool = true
    ) throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor {
        return try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try InternalFS.getSecurityInfo(forItemAt: path, members: members, followSymlink: followSymlink)
        }
    }
    
    
    public func setSecurityInfo(
        forItemAt path: FilePath,
        dacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        sacl: FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        owner: PlatformIdentity? = nil,
        group: PlatformIdentity? = nil,
        followSymlink: Bool = true
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
            try InternalFS.setSecurityInfo(
                forItemAt: path,
                setting: members,
                dacl: dacl.aclView,
                sacl: sacl.aclView,
                owner: owner?.rawId,
                group: group?.rawId,
                followSymlink: followSymlink
            )
        }
        
    }
    
    #else
    
    public func getPosixPermissions(forItemAt path: FilePath, followSymlink: Bool = true) throws(PlatformError) -> FilePermissions {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try InternalFS.getPosixPermissions(forItemAt: path, followSymlink: followSymlink)
        }
    }
    
    
    public func setPosixPermissions(forItemAt path: FilePath, permissions: FilePermissions, followSymlink: Bool = true) throws(PlatformError) {
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try InternalFS.setPosixPermissions(forItemAt: path, permissions: permissions, followSymlink: followSymlink)
        }
    }
    
    #endif
    
    
    public func getOwner(
        forItemAt path: FilePath,
        followSymlink: Bool = true
    ) throws(PlatformError) -> (owner: PlatformIdentity, group: PlatformIdentity) {
        try catchLowLevelError(operation: .fetchMeta(path)) { () throws(LowLevelError) in
            try InternalFS.getOwner(forItemAt: path, followSymlink: followSymlink)
        }
    }
    
    
    public func setOwner(forItemAt path: FilePath, owner: PlatformIdentity?, group: PlatformIdentity?, followSymlink: Bool = true) throws(PlatformError) {
        try catchLowLevelError(operation: .setMeta(path)) { () throws(LowLevelError) in
            try InternalFS.chown(forItemAt: path, owner: owner, group: group, followSymlink: followSymlink)
        }
    }
    
}
