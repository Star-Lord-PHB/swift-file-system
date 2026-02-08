import SystemPackage
import FileSystemCore


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
            return (try? InternalFS.getFileAttributes(forItemAt: path)) != nil
        }

        #else
        
        if followSymlinks {
            return (try? InternalFS.ustat(path)) != nil
        } else {
            return (try? InternalFS.ulstat(path)) != nil
        }

        #endif 

    }


    public func createFile(at path: FilePath, replaceExisting: Bool = false, permission: FilePermissions? = nil, content: ByteBuffer? = nil) throws(PlatformError) {

        try catchSystemError(operation: .createFile(path)) { () throws(SystemError) in 
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


    public func createDirectory(at path: FilePath, withIntermediateDirectories: Bool = false) throws(PlatformError) {

        if !withIntermediateDirectories {
            try catchSystemError(operation: .createDirectory(path)) { () throws(SystemError) in
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

        try catchSystemError(operation: .createDirectory(path)) { () throws(SystemError) in
            for component in components.reversed() {
                path.append(component)
                try InternalFS.mkdir(at: path, permissions: nil)
            }
        }

    }


    public func removeItem(at path: FilePath) throws(PlatformError) {

        do {
            try InternalFS.remove(itemAt: path)
            return 
        } catch let error where error.kind != .notEmptyDirectory {
            throw PlatformError(systemError: error, operation: .remove(path))
        } catch {
            // do nothing
        }

        try _removeDirectoryRecursive(at: path)

    }


    public func copyItem<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>(
        at srcPath: FilePath, 
        to dstPath: FilePath, 
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption = .overwrite, 
        symlinkOption: FileOperationOptions.CopyItemSymlinkOption = .copyLink,
        errorStrategy: ErrorStrategy = .abortOnError
    ) throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.ReturnedError {
        return try _copyItemImpl(
            at: srcPath, 
            to: dstPath, 
            onExistingTarget: targetExistOption, 
            symlinkOption: symlinkOption, 
            errorStrategy: errorStrategy
        )
    }


    // Unlike copyItem, moveItem will not merge directories and will not follow symlinks
    public func moveItem(
        at srcPath: FilePath, 
        to dstPath: FilePath, 
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption = .overwrite
    ) throws(PlatformError) {
        do {
            try InternalFS.rename(itemAt: srcPath, to: dstPath, replace: targetExistOption == .overwrite)
        } catch let error where error.kind == .alreadyExists && targetExistOption == .skip {
            return 
        } catch {
            throw PlatformError(
                systemError: error, 
                operation: .move(srcPath: srcPath, dstPath: dstPath)
            )
        } 
    }


    public func contentsOfDirectory(at path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) throws(PlatformError) -> [DirectoryEntry] {
        try DirectoryEntryDirectSequence(dirAt: path, options: options)
            .compactMap { (result) throws(PlatformError) in
                try result.get()
            }
    }


    public func createSymLink(at path: FilePath, pointingTo destPath: FilePath) throws(PlatformError) {
        try catchSystemError(operation: .createSymlink(linkPath: path, dstPath: destPath)) { () throws(SystemError) in
            try InternalFS.symlink(dstPath: destPath, linkPath: path)
        }
    }


    public func createHardLink(at path: FilePath, for existingPath: FilePath) throws(PlatformError) {
        try catchSystemError(operation: .createHardLink(linkPath: path, existingPath: existingPath)) { () throws(SystemError) in
            try InternalFS.link(existingPath: existingPath, newPath: path)
        }
    }


    public func destinationOfSymLink(at path: FilePath, recursive: Bool = true) throws(PlatformError) -> FilePath {
        if recursive {
            try catchSystemError(operation: .recursiveResolveSymlink(path)) { () throws(SystemError) in
                try InternalFS.realpath(of: path)
            }
        } else {
            try catchSystemError(operation: .readSymlink(path)) { () throws(SystemError) in
                try InternalFS.readlink(fromSymlinkAt: path)
            }
        }
    }

}



extension FileSystem {

    public func info(ofFileAt path: FilePath, followSymlinks: Bool = false) throws(PlatformError) -> FileInfo {
        return try .init(fileAt: path, followSymLink: followSymlinks)
    }


    public func setTimes(
        forItemAt path: FilePath, 
        accessTime: FileTimeSpec? = nil, 
        modificationTime: FileTimeSpec? = nil, 
        creationTime: FileTimeSpec? = nil
    ) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.setFileTimes(
                forItemAt: path, 
                access: accessTime, 
                modification: modificationTime,
                creation: creationTime
            )
        }
    }


    public func setAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes) throws(PlatformError) {

        #if canImport(Glibc) || canImport(Musl)
        try self.setInodeFlags(forItemAt: path, flags: InternalFS.fileAttributesToInodeFlags(attributes))
        #else 
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.setFileAttributes(forItemAt: path, attributes: attributes)
        }
        #endif 

    }


    #if canImport(Glibc) || canImport(Musl)
    public func getInodeFlags(forItemAt path: FilePath) throws(PlatformError) -> CInt {
        try catchSystemError(operation: .fetchMeta(path)) { () throws(SystemError) in
            try InternalFS.readFileInodeFlags(forItemAt: path)
        }
    }


    public func setInodeFlags(forItemAt path: FilePath, flags: CInt) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.setFileInodeFlags(forItemAt: path, flags: flags)
        }
    }
    #endif


    public func setPermissions(forItemAt path: FilePath, permissions: FilePermissions) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            #if canImport(WinSDK)
            let daclPtr = try WindowsAPI.dacl(fromPosixPermissions: permissions)
            try InternalFS.setFileSecurityInfo(
                forItemAt: path, 
                setting: .dacl, 
                dacl: .init(pacl: daclPtr), sacl: nil, owner: nil, group: nil
            )
            #else 
            try InternalFS.setFilePermissions(forItemAt: path, permissions: permissions)
            #endif
        }
    }


    public func setOwner(forItemAt path: FilePath, owner: PlatformIdentity?, group: PlatformIdentity?) throws(PlatformError) {
        try catchSystemError(operation: .setMeta(path)) { () throws(SystemError) in
            try InternalFS.chown(forItemAt: path, owner: owner, group: group)
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



extension FileSystem {

    public func currentWorkingDirectoryPath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryCurrentWorkingDir) { () throws(SystemError) in
            try InternalFS.currentWorkingDirectoryPath()
        }
    }


    public func executablePath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryExecutablePath) { () throws(SystemError) in
            try InternalFS.executablePath()
        }
    }


    public func tempDirectoryPath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryTempDir) { () throws(SystemError) in
            try InternalFS.tmpDirectoryPath()
        }
    }


    public func homeDirectoryPath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryHomeDir) { () throws(SystemError) in
            try InternalFS.homeDirectoryPath()
        }
    }


    public func cacheDirectoryPath() throws(PlatformError) -> FilePath {
        try catchSystemError(operation: .queryCacheDir) { () throws(SystemError) in
            try InternalFS.cacheDirectoryPath()
        }
    }

}