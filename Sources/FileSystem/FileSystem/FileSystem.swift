import SystemPackage
import PlatformCLib


public final class FileSystem: FileSystemProtocal {

    public init() {}

}



extension FileSystem {

    public func itemExists(at path: FilePath, followSymlinks: Bool = false) -> Bool {

        #if canImport(WinSDK)

        if followSymlinks {
            return (try? UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .none, noFollow: false, platformSpecificOptions: .windows.backupSemantics)
            )) != nil
        } else {
            return path.withPlatformString {
                GetFileAttributesW($0) != INVALID_FILE_ATTRIBUTES
            }
        }

        #else
        
        if followSymlinks {
            return (try? InternalFS.ustat(path)) != nil
        } else {
            return (try? InternalFS.ulstat(path)) != nil
        }

        #endif 

    }


    public func createFile(at path: FilePath, replaceExisting: Bool = false, permission: FilePermissions? = nil, content: ByteBuffer? = nil) throws(FileError) {

        try catchSystemError(
            operationDescription: .creatingFile(at: path, replaceExisting: replaceExisting, permission: permission)
        ) { () throws(SystemError) in 
            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .writeOnly(), creation: replaceExisting ? .createIfMissing : .assertMissing, truncate: replaceExisting),
                creationPermissions: permission
            )
            if let content {
                try content.withUnsafeBytesTypedThrow { (ptr) throws(SystemError) in 
                    _ = try handle.write(contentsOf: ptr)
                }
            }
            try handle.close()
        }

    }


    public func createDirectory(at path: FilePath, withIntermediateDirectories: Bool = false) throws(FileError) {

        if !withIntermediateDirectories {
            try catchSystemError(
                operationDescription: .createDir(at: path, withIntermediateDirectories: withIntermediateDirectories)
            ) { () throws(SystemError) in
                try InternalFS.mkdir(at: path, permissions: nil)
            }
            return
        }

        var path = path
        var components = [] as [FilePath.Component]

        while let component = path.lastComponent, !itemExists(at: path) {
            path.removeLastComponent()
            components.append(component)
        }

        for component in components.reversed() {
            path.append(component)
            try catchSystemError(
                operationDescription: .createDir(at: path, withIntermediateDirectories: withIntermediateDirectories)
            ) { () throws(SystemError) in
                try InternalFS.mkdir(at: path, permissions: nil)
            }
        }

    }


    public func removeItem(at path: FilePath) throws(FileError) {

        do {
            try InternalFS.remove(itemAt: path)
            return 
        } catch let error where error.kind != .notEmptyDirectory {
            throw FileError(systemError: error, operationDescription: .removingItem(at: path))
        } catch {
            // do nothing
        }

        try catchSystemError(operationDescription: .removingItem(at: path)) { () throws(SystemError) in
            try _removeDirectoryRecursive(at: path)
        }

    }


    public func copyItem(
        at srcPath: FilePath, 
        to dstPath: FilePath, 
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption = .overwrite, 
        symlinkOption: FileOperationOptions.CopyItemSymlinkOption = .copyLink
    ) throws(FileError) {

        let copyOption = switch targetExistOption {
            case .error:     .none
            case .overwrite: .replace
            case .skip:      .skip
        } as CopyOverwriteOption

        let srcPath = try catchSystemError(operationDescription: .copyingItem(from: srcPath, to: dstPath)) { () throws(SystemError) in
            // resolve symlink first if needed
            symlinkOption == .copyTarget ? try InternalFS.realpath(of: srcPath) : srcPath
        }

        try catchSystemError(operationDescription: .copyingItem(from: srcPath, to: dstPath)) { () throws(SystemError) in
            try _copyItemNoFollow(from: srcPath, to: dstPath, overwrite: copyOption)
        }

    }


    // Unlike copyItem, moveItem will not merge directories and will not follow symlinks
    public func moveItem(
        at srcPath: FilePath, 
        to dstPath: FilePath, 
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption = .overwrite
    ) throws(FileError) {
        do {
            try InternalFS.rename(itemAt: srcPath, to: dstPath, replace: targetExistOption == .overwrite)
        } catch let error where error.kind == .alreadyExists && targetExistOption == .skip {
            return 
        } catch {
            throw FileError(
                systemError: error, 
                operationDescription: .movingItem(from: srcPath, to: dstPath)
            )
        } 
    }


    public func contentsOfDirectory(at path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = [.skipDotEntries]) throws(FileError) -> [DirectoryEntry] {
        try DirectoryEntrySequence(dirAt: path).compactMap {
            guard case .success(.entry(let entry)) = $0 else { return nil }
            if options.contains(.skipDotEntries) && entry.path.lastComponent?.kind != .regular {
                return nil
            }
            if options.contains(.skipDir) && entry.type == .directory {
                return nil
            }
            return entry
        }
    }


    public func createSymLink(at path: FilePath, pointingTo destPath: FilePath) throws(FileError) {
        try catchSystemError(operationDescription: .creatingSymlink(at: path, pointingTo: destPath)) { () throws(SystemError) in
            try InternalFS.symlink(dstPath: destPath, linkPath: path)
        }
    }


    public func createHardLink(at path: FilePath, for existingPath: FilePath) throws(FileError) {
        try catchSystemError(operationDescription: .creatingHardlink(at: path, for: existingPath)) { () throws(SystemError) in
            try InternalFS.link(existingPath: existingPath, newPath: path)
        }
    }


    public func destinationOfSymLink(at path: FilePath, recursive: Bool = true) throws(FileError) -> FilePath {
        try catchSystemError(operationDescription: .readingSymlink(at: path)) { () throws(SystemError) in
            if recursive {
                try InternalFS.realpath(of: path)
            } else {
                try InternalFS.readlink(fromSymlinkAt: path)
            }
        }
    }

}



extension FileSystem {

    public func info(ofFileAt path: FilePath, followSymlinks: Bool = false) throws(FileError) -> FileInfo {
        return try .init(fileAt: path, followSymLink: followSymlinks)
    }


    public func setTimes(
        forItemAt path: FilePath, 
        accessTime: FileTimeSpec? = nil, 
        modificationTime: FileTimeSpec? = nil, 
        creationTime: FileTimeSpec? = nil
    ) throws(FileError) {

        try catchSystemError(operationDescription: .settingFileTimes(at: path)) { () throws(SystemError) in
            try InternalFS.setFileTimes(
                forItemAt: path, 
                access: accessTime?.platformFileTime, 
                modification: modificationTime?.platformFileTime,
                creation: creationTime?.platformFileTime
            )
        }

    }


    public func setAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes) throws(FileError) {

        #if canImport(Glibc) || canImport(Musl)

        var inodeFlags = 0 as CInt

        // Map statx attributes to inode flags
        if attributes.isCompressed { inodeFlags |= FS_COMPR_FL }
        if attributes.isImmutable { inodeFlags |= FS_IMMUTABLE_FL }
        if attributes.isAppendOnly { inodeFlags |= FS_APPEND_FL }
        if attributes.noDump { inodeFlags |= FS_NODUMP_FL }
        if attributes.isEncrypted { inodeFlags |= FS_ENCRYPT_FL }
        if attributes.isVerityProtected { inodeFlags |= FS_VERITY_FL }

        try self.setInodeFlags(forItemAt: path, flags: inodeFlags)

        #else 

        try catchSystemError(operationDescription: .settingFileAttributes(at: path)) { () throws(SystemError) in
            try InternalFS.setFileAttributes(forItemAt: path, attributes: attributes.rawValue)
        }

        #endif 

    }


    #if canImport(Glibc) || canImport(Musl)
    public func getInodeFlags(forItemAt path: FilePath) throws(FileError) -> CInt {
        try catchSystemError(operationDescription: .gettingFileInodeFlags(at: path)) { () throws(SystemError) in
            try InternalFS.readFileInodeFlags(forItemAt: path)
        }
    }


    public func setInodeFlags(forItemAt path: FilePath, flags: CInt) throws(FileError) {
        try catchSystemError(operationDescription: .settingFileInodeFlags(at: path)) { () throws(SystemError) in
            try InternalFS.setFileInodeFlags(forItemAt: path, flags: flags)
        }
    }
    #endif


    public func setPermissions(forItemAt path: FilePath, permissions: FilePermissions) throws(FileError) {
        try catchSystemError(operationDescription: .settingFilePermissions(at: path)) { () throws(SystemError) in
            try InternalFS.setFilePermissions(forItemAt: path, permissions: permissions)
        }
    }


    public func setOwner(forItemAt path: FilePath, owner: PlatformIdentity?, group: PlatformIdentity?) throws(FileError) {
        try catchSystemError(operationDescription: .settingFileOwner(at: path)) { () throws(SystemError) in
            try InternalFS.chown(forItemAt: path, owner: owner?.rawId, group: group?.rawId)
        }
    }


    #if canImport(WinSDK)
    public func getSecurityInfo(
        forItemAt path: FilePath, 
        querying members: FileOperationOptions.WindowsSecurityDescriptorMembers = .all
    ) throws(FileError) -> WindowsSelfRelativeSecurityDescriptor {

        var internalQueryingMembers = [] as InternalFS.WindowsSecurityInfoMembers

        if members.contains(.owner) { internalQueryingMembers.insert(.owner) }
        if members.contains(.group) { internalQueryingMembers.insert(.group) }
        if members.contains(.dacl) { internalQueryingMembers.insert(.dacl) }
        if members.contains(.sacl) { internalQueryingMembers.insert(.sacl) }

        return try catchSystemError(operationDescription: .gettingFileSecurityInfo(at: path)) { () throws(SystemError) in
            try InternalFS.getSecurityInfo(forItemAt: path, members: internalQueryingMembers)
        }

    }


    public func setSecurityInfo(
        forItemAt path: FilePath, 
        dacl: consuming FileOperationOptions.WindowsAclUpdateRequest = .noChange, 
        sacl: consuming FileOperationOptions.WindowsAclUpdateRequest = .noChange, 
        owner: PlatformIdentity? = nil, 
        group: PlatformIdentity? = nil
    ) throws(FileError) {

        var members = [] as InternalFS.WindowsSecurityInfoMembers

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
            throw FileError(systemError: error, operationDescription: .settingFileSecurityInfo(at: path))
        }

    }
    #endif

}



extension FileSystem {

    public func withFileHandle<R: ~Copyable>(
        forReadingAt path: FilePath, 
        options: FileOperationOptions.OpenForReading, 
        body: (borrowing ReadFileHandle) throws -> R
    ) throws -> R {
        let handle = try ReadFileHandle(forFileAt: path, options: options)

        let result: R
        do {
            result = try body(handle)
        } catch {
            try? handle.close()
            throw error
        }

        try handle.close()
        return result
    }


    public func withFileHandle<R: ~Copyable>(
        forWritingAt path: FilePath, 
        option: FileOperationOptions.OpenForWriting, 
        body: (borrowing WriteFileHandle) throws -> R
    ) throws -> R {

        let handle = try WriteFileHandle(forFileAt: path, options: option)

        let result: R
        do {
            result = try body(handle)
        } catch {
            try? handle.close()
            throw error
        }

        try handle.close()
        return result

    }


    public func withFileHandle<R: ~Copyable>(
        forUpdatingAt path: FilePath, 
        option: FileOperationOptions.OpenForWriting, 
        body: (borrowing ReadWriteFileHandle) throws -> R
    ) throws -> R {

        let handle = try ReadWriteFileHandle(forFileAt: path, options: option)

        let result: R
        do {
            result = try body(handle)
        } catch {
            try? handle.close()
            throw error
        }

        try handle.close()
        return result

    }


    public func withDirHandle<R: ~Copyable>(
        at path: FilePath, 
        options: FileOperationOptions.OpenForDirectory, 
        body: (borrowing DirectoryHandle) throws -> R
    ) throws -> R {

        let handle = try DirectoryHandle(forDirAt: path, options: options)

        let result: R
        do {
            result = try body(handle)
        } catch {
            try? handle.close()
            throw error
        }

        try handle.close()
        return result

    }

}