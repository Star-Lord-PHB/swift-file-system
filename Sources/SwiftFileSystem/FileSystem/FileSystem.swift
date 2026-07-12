import SystemPackage
import FileSystemCore


public struct FileSystem: FileSystemProtocal {

    public init() {}

}



extension FileSystem {

    public func itemExists(at path: FilePath, followSymlinks: Bool = true) -> Bool {

        #if canImport(WinSDK)

        if followSymlinks {
            return (try? UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .none, noFollow: false, platformSpecificOptions: .windows.backupSemantics)
            )) != nil
        } else {
            return (try? InternalFS.getFileAttributes(forItemAt: path, followSymlink: followSymlinks)) != nil
        }

        #else
        
        if followSymlinks {
            return (try? InternalFS.ustat(path)) != nil
        } else {
            return (try? InternalFS.ulstat(path)) != nil
        }

        #endif 

    }


    public func createFile(at path: FilePath, replaceExisting: Bool = false, permissions: FilePermissions? = nil, content: ByteBuffer? = nil) throws(PlatformError) {

        try catchSystemError(operation: .createFile(path)) { () throws(SystemError) in 
            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .writeOnly(), creation: replaceExisting ? .createIfMissing : .assertMissing, truncate: replaceExisting),
                creationPermissions: permissions
            )
            if let content {
                try content.withUnsafeBytes { (ptr) throws(SystemError) in 
                    _ = try handle.write(contentsOf: ptr)
                }
            }
            try handle.close()
        }

    }


    public func createDirectory(at path: FilePath, withIntermediateDirectories: Bool = false, permissions: FilePermissions? = nil) throws(PlatformError) {

        if !withIntermediateDirectories {
            try catchSystemError(operation: .createDirectory(path)) { () throws(SystemError) in
                try InternalFS.mkdir(at: path, permissions: permissions)
            }
            return
        }

        var path = path
        var components = [] as [FilePath.Component]

        while let component = path.lastComponent, !itemExists(at: path) {
            path.removeLastComponent()
            components.append(component)
        }

        guard !components.isEmpty else { return }

        try catchSystemError(operation: .createDirectory(path)) { () throws(SystemError) in
            for component in components.suffix(from: 1).reversed() {
                path.append(component)
                try InternalFS.mkdir(at: path, permissions: nil)
            }
            // permission will only be applied to the leaf directory
            path.append(components.first!)
            try InternalFS.mkdir(at: path, permissions: permissions)
        }

    }


    #if canImport(WinSDK)

    public func createFile(at path: FilePath, replaceExisting: Bool = false, permissions: WindowsSecurityDescriptorView, content: ByteBuffer? = nil) throws(PlatformError) {

        try catchSystemError(operation: .createFile(path)) { () throws(SystemError) in 
            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .writeOnly(), creation: replaceExisting ? .createIfMissing : .assertMissing, truncate: replaceExisting),
                creationPermissions: permissions
            )
            if let content {
                try content.withUnsafeBytes { (ptr) throws(SystemError) in 
                    _ = try handle.write(contentsOf: ptr)
                }
            }
            try handle.close()
        }

    }

    public func createDirectory(at path: FilePath, withIntermediateDirectories: Bool = false, permissions: WindowsSecurityDescriptorView) throws(PlatformError) {

        if !withIntermediateDirectories {
            try catchSystemError(operation: .createDirectory(path)) { () throws(SystemError) in
                try InternalFS.mkdir(at: path, permissions: permissions)
            }
            return
        }

        var path = path
        var components = [] as [FilePath.Component]

        while let component = path.lastComponent, !itemExists(at: path) {
            path.removeLastComponent()
            components.append(component)
        }

        guard !components.isEmpty else { return }

        try catchSystemError(operation: .createDirectory(path)) { () throws(SystemError) in
            for component in components.suffix(from: 1).reversed() {
                path.append(component)
                try InternalFS.mkdir(at: path, permissions: nil)
            }
            // permission will only be applied to the leaf directory
            path.append(components.first!)
            try InternalFS.mkdir(at: path, permissions: permissions)
        }

    }

    #endif


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
