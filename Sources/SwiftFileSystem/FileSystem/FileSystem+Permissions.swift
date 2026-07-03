import SystemPackage
import FileSystemCore


extension FileSystem {
    
    public func canAccess(
        itemAt path: FilePath,
        for accessMode: FileOperationOptions.FileAccessMode = [.read, .write],
        followSymlink: Bool = true
    ) throws(PlatformError) -> Bool {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try InternalFS.canAccess(itemAt: path, for: accessMode, followSymlink: followSymlink)
        }
    }
    
    
    #if canImport(WinSDK)
    
    public func getSecurityInfo(
        forItemAt path: FilePath,
        querying members: FileOperationOptions.WindowsSecurityInfoMembers = .all
    ) throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor {
        return try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try InternalFS.getSecurityInfo(forItemAt: path, members: members)
        }
    }
    
    
    public func setSecurityInfo(
        forItemAt path: FilePath,
        dacl: consuming FileOperationOptions.WindowsAclUpdateRequest = .noChange,
        sacl: consuming FileOperationOptions.WindowsAclUpdateRequest = .noChange,
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
        
        do {
            try InternalFS.setFileSecurityInfo(
                forItemAt: path,
                setting: members,
                dacl: dacl.takeRawAcl(),
                sacl: sacl.takeRawAcl(),
                owner: owner?.rawId,
                group: group?.rawId
            )
        } catch {
            throw PlatformError(systemError: error, operation: .setMeta(path))
        }
        
    }
    
    #else
    
    public func getPosixPermissions(forItemAt path: FilePath, followSymlink: Bool = true) throws(PlatformError) -> FilePermissions {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try InternalFS.getPosixPermissions(forItemAt: path, followSymlink: followSymlink)
        }
    }
    
    
    public func setPosixPermissions(forItemAt path: FilePath, permissions: FilePermissions, followSymlink: Bool = true) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.setPosixPermissions(forItemAt: path, permissions: permissions, followSymlink: followSymlink)
        }
    }
    
    #endif
    
    
    public func getOwner(
        forItemAt path: FilePath,
        followSymlink: Bool = true
    ) throws(PlatformError) -> (owner: PlatformIdentity, group: PlatformIdentity) {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try InternalFS.getOwner(forItemAt: path, followSymlink: followSymlink)
        }
    }
    
    
    public func setOwner(forItemAt path: FilePath, owner: PlatformIdentity?, group: PlatformIdentity?) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.chown(forItemAt: path, owner: owner, group: group)
        }
    }
    
}
