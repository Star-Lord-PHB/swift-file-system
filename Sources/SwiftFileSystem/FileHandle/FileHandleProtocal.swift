import SystemPackage
import FileSystemCore



public protocol FileHandleProtocol: ~Copyable {

    var path: FilePath { get }

    consuming func close() throws(PlatformError)

    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R

}



extension FileHandleProtocol where Self: ~Copyable {

    public func fileInfo() throws(PlatformError) -> FileInfo {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.fileInfo()
            }
        }
    }


    public func type() throws(PlatformError) -> FileType {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try self.withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.type()
            }
        }
    }


    public func fileTimes() throws(PlatformError) -> FileTimes {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.fileTimes()
            }
        }
    }


    public func setFileTimes(
        access: FileTimeSpec? = nil, 
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.setFileTimes(access: access, modification: modification, creation: creation)
            }
        }
    }


    public func fileAttributes() throws(PlatformError) -> PlatformFileAttributes {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.fileAttributes()
            }
        }
    }


    public func setFileAttributes(_ attributes: PlatformFileAttributes) throws(PlatformError) {
        #if canImport(Glibc) || canImport(Musl)
        try self.setInodeFlags(InternalFS.fileAttributesToInodeFlags(attributes))
        #else 
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.setFileAttributes(attributes)
            }
        }
        #endif
    }


    #if canImport(Glibc) || canImport(Musl)
    public func inodeFlags() throws(PlatformError) -> CInterop.PosixInodeFlags {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.fileInodeFlags()
            }
        }
    }


    public func setInodeFlags(_ flags: CInterop.PosixInodeFlags) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.setFileInodeFlags(flags)
            }
        }
    }
    #endif


    #if canImport(WinSDK)
    public func securityInfo(
        _ members: FileOperationOptions.WindowsSecurityInfoMembers = .all
    ) throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor {
        return try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.securityInfo(members)
            }
        }
    }


    public func setSecurityInfo(
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

        var dacl = Optional<FileOperationOptions.WindowsAclUpdateRequest>.some(dacl)
        var sacl = Optional<FileOperationOptions.WindowsAclUpdateRequest>.some(sacl)

        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                let dacl = dacl.take() 
                let sacl = sacl.take()  
                try sysHandle.setSecurityInfo(
                    members, 
                    dacl: dacl!.takeRawAcl(), 
                    sacl: sacl!.takeRawAcl(), 
                    owner: owner?.rawId, 
                    group: group?.rawId
                )
            }
        }

    }
    #else
    public func posixPermissions() throws(PlatformError) -> FilePermissions {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.posixPermissions()
            }
        }
    }
    
    public func setPosixPermissions(_ permissions: FilePermissions) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.setPosixPermissions(permissions)
            }
        }
    }
    #endif
    
    
    public func owner() throws(PlatformError) -> (owner: PlatformIdentity?, group: PlatformIdentity?) {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in
                try sysHandle.owner()
            }
        }
    }


    public func setOwner(owner: PlatformIdentity?, group: PlatformIdentity?) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in
                try sysHandle.fchown(owner: owner, group: group)
            }
        }
    }

}



public protocol SeekableFileHandleProtocol: ~Copyable, FileHandleProtocol {

    @discardableResult
    func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64

}



extension SeekableFileHandleProtocol where Self: ~Copyable {

    public var currentOffset: Int64 {
        get throws(PlatformError) {
            try seek(to: 0, relativeTo: .current)
        }
    }

}



public protocol ReadFileHandleProtocol: ~Copyable, SeekableFileHandleProtocol {

    func read(fromOffset offset: Int64?, length: Int64?, into buffer: inout ByteBuffer) throws(PlatformError)

}



extension ReadFileHandleProtocol where Self: ~Copyable {

    public func read(length: Int64? = nil, into buffer: inout ByteBuffer) throws(PlatformError) {
        try read(fromOffset: nil, length: length, into: &buffer)
    }


    public func read(fromOffset offset: Int64?, into buffer: inout ByteBuffer) throws(PlatformError) {
        try read(fromOffset: offset, length: Int64(buffer.count), into: &buffer)
    }


    public func read(fromOffset offset: Int64? = nil, length: Int64) throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        try read(fromOffset: offset, length: length, into: &buffer)
        return buffer
    }

}



public protocol WriteFileHandleProtocol: ~Copyable, SeekableFileHandleProtocol {

    func write(_ data: ByteBuffer, toOffset offset: Int64?) throws(PlatformError) -> Int64

    func resize(to size: Int64) throws(PlatformError)

    func synchronize() throws(PlatformError)

}



extension WriteFileHandleProtocol where Self: ~Copyable {

    public func write(_ data: ByteBuffer) throws(PlatformError) -> Int64 {
        try write(data, toOffset: nil)
    }

}



public typealias ReadWriteFileHandleProtocol = ReadFileHandleProtocol & WriteFileHandleProtocol



public protocol DirectoryHandleProtocol: ~Copyable, FileHandleProtocol {

    // MARK: TODO: Migrate to associatedtype when non-copyable associated types in protocols are supported
    // associatedtype DirectoryEntryDirectSequenceType: DirectoryEntryDirectSequenceProtocol & ~Escapable & ~Copyable
    // associatedtype DirectoryEntryRecursiveSequenceType: DirectoryEntryRecursiveSequenceProtocol & ~Escapable & ~Copyable
    typealias DirectoryEntryRecursiveSequenceType = any (DirectoryEntryRecursiveSequenceProtocol & ~Escapable & ~Copyable)
    typealias DirectoryEntryDirectSequenceType = any (DirectoryEntryDirectSequenceProtocol & ~Escapable & ~Copyable)

    func directEntries(options: FileOperationOptions.DirectoryTraversalOption) throws(PlatformError) -> [DirectoryEntry]

    @_lifetime(borrow self)
    func entryDirectSequence(options: FileOperationOptions.DirectoryTraversalOption) -> DirectoryEntryDirectSequenceType

    @_lifetime(borrow self)
    func entryRecursiveSequence(options: FileOperationOptions.DirectoryTraversalOption) -> DirectoryEntryRecursiveSequenceType

}
