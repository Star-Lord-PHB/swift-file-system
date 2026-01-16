import SystemPackage
import Foundation



public protocol FileHandleProtocol: ~Copyable {

    var path: FilePath { get }

    consuming func close() throws(FileError)

    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R

}



extension FileHandleProtocol where Self: ~Copyable {

    public func fileInfo() throws(FileError) -> FileInfo {
        try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try .init(unsafeSystemHandle: sysHandle)
            }
        }
    }


    public func type() throws(FileError) -> FileType {
        try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try self.withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.type()
            }
        }
    }


    public func fileTimes() throws(FileError) -> FileTimes {
        try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.fileTimes()
            }
        }
    }


    public func setFileTimes(
        access: FileTimeSpec? = nil, 
        modification: FileTimeSpec? = nil,
        creation: FileTimeSpec? = nil
    ) throws(FileError) {
        try catchSystemError(operationDescription: .settingFileTimes(at: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.setFileTimes(access: access, modification: modification, creation: creation)
            }
        }
    }


    public func fileAttributes() throws(FileError) -> PlatformFileAttributes {
        try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.fileAttributes()
            }
        }
    }


    public func setFileAttributes(_ attributes: PlatformFileAttributes) throws(FileError) {
        #if canImport(Glibc) || canImport(Musl)
        try self.setInodeFlags(InternalFS.fileAttributesToInodeFlags(attributes))
        #else 
        try catchSystemError(operationDescription: .settingFileAttributes(at: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.setFileAttributes(attributes)
            }
        }
        #endif
    }


    #if canImport(Glibc) || canImport(Musl)
    public func inodeFlags() throws(FileError) -> CInterop.PosixInodeFlags {
        try catchSystemError(operationDescription: .fetchingInfo(for: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.fileInodeFlags()
            }
        }
    }


    public func setInodeFlags(_ flags: CInterop.PosixInodeFlags) throws(FileError) {
        try catchSystemError(operationDescription: .settingFileInodeFlags(at: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.setFileInodeFlags(flags)
            }
        }
    }
    #endif


    #if canImport(WinSDK)
    public func securityInfo(
        _ members: FileOperationOptions.WindowsSecurityDescriptorMembers = .all
    ) throws(FileError) -> WindowsSelfRelativeSecurityDescriptor {
        var internalQueryingMembers = [] as WindowsSecurityInfoMembers

        if members.contains(.owner) { internalQueryingMembers.insert(.owner) }
        if members.contains(.group) { internalQueryingMembers.insert(.group) }
        if members.contains(.dacl) { internalQueryingMembers.insert(.dacl) }
        if members.contains(.sacl) { internalQueryingMembers.insert(.sacl) }

        return try catchSystemError(operationDescription: .gettingFileSecurityInfo(at: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.securityInfo(internalQueryingMembers)
            }
        }
    }


    public func setSecurityInfo(
        dacl: consuming FileOperationOptions.WindowsAclUpdateRequest = .noChange, 
        sacl: consuming FileOperationOptions.WindowsAclUpdateRequest = .noChange, 
        owner: PlatformIdentity? = nil, 
        group: PlatformIdentity? = nil
    ) throws(FileError) {
        
        var members = [] as WindowsSecurityInfoMembers

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

        try catchSystemError(operationDescription: .settingFileSecurityInfo(at: path)) { () throws(SystemError) in
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
    #endif


    public func setPermissions(_ permissions: FilePermissions) throws(FileError) {
        try catchSystemError(operationDescription: .settingFilePermissions(at: path)) { () throws(SystemError) in
            #if canImport(WinSDK)
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                let daclPtr = try WindowsAPI.dacl(fromPosixPermissions: permissions)
                try sysHandle.setSecurityInfo(.dacl, dacl: .init(pacl: daclPtr), sacl: nil, owner: nil, group: nil)
            }
            #else     
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.setPermissions(permissions)
            }
            #endif
        }
    }


    public func setOwner(owner: PlatformIdentity?, group: PlatformIdentity?) throws(FileError) {
        try catchSystemError(operationDescription: .settingFileOwner(at: path)) { () throws(SystemError) in
            try withUnsafeSystemHandle { (sysHandle) throws(SystemError) in 
                try sysHandle.fchown(owner: owner, group: group)
            }
        }
    }

}



public protocol SeekableFileHandleProtocol: ~Copyable, FileHandleProtocol {

    @discardableResult
    func seek(to offset: Int64, relativeTo whence: UnsafeSystemHandle.SeekWhence) throws(FileError) -> Int64

}



extension SeekableFileHandleProtocol where Self: ~Copyable {

    public var currentOffset: Int64 {
        get throws(FileError) {
            try seek(to: 0, relativeTo: .current)
        }
    }

}



public protocol ReadFileHandleProtocol: ~Copyable, SeekableFileHandleProtocol {

    func read(fromOffset offset: Int64?, length: Int64?, into buffer: inout ByteBuffer) throws(FileError)

}



extension ReadFileHandleProtocol where Self: ~Copyable {

    public func read(length: Int64? = nil, into buffer: inout ByteBuffer) throws(FileError) {
        try read(fromOffset: nil, length: length, into: &buffer)
    }


    public func read(fromOffset offset: Int64?, into buffer: inout ByteBuffer) throws(FileError) {
        try read(fromOffset: offset, length: Int64(buffer.count), into: &buffer)
    }


    public func read(fromOffset offset: Int64? = nil, length: Int64) throws(FileError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        try read(fromOffset: offset, length: length, into: &buffer)
        return buffer
    }

}



public protocol WriteFileHandleProtocol: ~Copyable, SeekableFileHandleProtocol {

    func write(_ data: some ContiguousBytes, toOffset offset: Int64?) throws(FileError) -> Int64

    func resize(to size: Int64) throws(FileError)

    func synchronize() throws(FileError)

}



extension WriteFileHandleProtocol where Self: ~Copyable {

    public func write(_ data: some ContiguousBytes) throws(FileError) -> Int64 {
        try write(data, toOffset: nil)
    }

}



public typealias ReadWriteFileHandleProtocol = ReadFileHandleProtocol & WriteFileHandleProtocol



public protocol DirectoryHandleProtocol: ~Copyable, FileHandleProtocol {

    // TODO: Migrate to associatedtype when non-copyable associated types in protocols are supported
    // associatedtype DirectoryEntrySequenceType: DirectoryEntrySequenceProtocol & ~Escapable & ~Copyable 
    typealias DirectoryEntrySequenceType = any (DirectoryEntrySequenceProtocol & ~Escapable & ~Copyable)

    func directEntries() throws(FileError) -> [DirectoryEntry]

    @_lifetime(borrow self)
    func entrySequence(recursive: Bool) throws(FileError) -> DirectoryEntrySequenceType

}