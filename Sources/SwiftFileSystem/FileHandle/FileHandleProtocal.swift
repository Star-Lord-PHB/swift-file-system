import SystemPackage
import FileSystemCore



public protocol FileHandleProtocol: ~Copyable {

    var path: FilePath { get }

    consuming func close() throws(PlatformError)

    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R

}



extension FileHandleProtocol where Self: ~Copyable {

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



public protocol SeekableFileHandleProtocol: ~Copyable, FileHandleProtocol {

    @discardableResult
    func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence) throws(PlatformError) -> Int64

}



extension SeekableFileHandleProtocol where Self: ~Copyable {

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



public protocol ReadFileHandleProtocol: ~Copyable, SeekableFileHandleProtocol {

    func read(fromOffset offset: Int64?, into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64

}



extension ReadFileHandleProtocol where Self: ~Copyable {

    public func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64 {
        return try read(fromOffset: nil, into: &buffer)
    }


    public func read(fromOffset offset: Int64? = nil, into buffer: consuming MutableRawSpan) throws(PlatformError) -> Int64 {
        return try read(fromOffset: offset, into: &buffer)
    }


    public func read(
        fromOffset offset: Int64? = nil,
        into buffer: inout ByteBuffer,
        at bufferRange: some RangeExpression<Int> = 0...
    ) throws(PlatformError) -> Int64 {
        return try read(fromOffset: offset, into: buffer.mutableBytes._consumingExtracting(bufferRange))
    }


    public func read(fromOffset offset: Int64? = nil, length: Int64) throws(PlatformError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        let bytesRead = try read(fromOffset: offset, into: &buffer, at: ..<Int(length))
        buffer.removeLast(Int(Int64(buffer.count) - bytesRead))
        return buffer
    }

}



public protocol WriteFileHandleProtocol: ~Copyable, SeekableFileHandleProtocol {
    
    @discardableResult
    func write(_ buffer: RawSpan, toOffset offset: Int64?) throws(PlatformError) -> Int64

    func resize(to size: Int64) throws(PlatformError)

    func synchronize() throws(PlatformError)

}



extension WriteFileHandleProtocol where Self: ~Copyable {
    
    @discardableResult
    func write(_ buffer: RawSpan) throws(PlatformError) -> Int64 {
        return try write(buffer, toOffset: nil)
    }
    
    
    @discardableResult
    public func write(_ data: ByteBuffer, toOffset offset: Int64? = nil) throws(PlatformError) -> Int64 {
        return try write(data.bytes, toOffset: offset)
    }

}



public protocol AppendableFileHandleProtocol: ~Copyable, FileHandleProtocol {

    @discardableResult
    func append(_ buffer: RawSpan) throws(PlatformError) -> Int64

}



extension AppendableFileHandleProtocol where Self: ~Copyable {
    
    @discardableResult
    public func append(_ data: ByteBuffer) throws(PlatformError) -> Int64 {
        return try append(data.bytes)
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
