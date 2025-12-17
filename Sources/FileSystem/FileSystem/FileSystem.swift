import SystemPackage
// import PlatformCLib
import CFileSystem


public final class FileSystem: FileSystemProtocal {

    public init() {}


    public func info(ofFileAt path: FilePath, followSymlinks: Bool = false) throws(FileError) -> FileInfo {
        return try .init(fileAt: path, followSymLink: followSymlinks)
    }


    public func itemExists(at path: FilePath, followSymlinks: Bool = false) -> Bool {

        #if canImport(WinSDK)

        if followSymlinks {
            return (try? InternalFS.ustat(path)) != nil
        } else {
            return GetFileAttributesW(path.string.wideCString) != INVALID_FILE_ATTRIBUTES
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

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")
      
        #else

        let srcPath = try catchSystemError(operationDescription: .copyingItem(from: srcPath, to: dstPath)) { () throws(SystemError) in
            // resolve symlink first if needed
            symlinkOption == .copyTarget ? try InternalFS.realpath(of: srcPath) : srcPath
        }

        try catchSystemError(operationDescription: .copyingItem(from: srcPath, to: dstPath)) { () throws(SystemError) in
            try _copyItemNoFollow(from: srcPath, to: dstPath, overwrite: copyOption)
        }

        #endif

    }


    // Unlike copyItem, moveItem will not merge directories and will not follow symlinks
    public func moveItem(
        at srcPath: FilePath, 
        to dstPath: FilePath, 
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption = .overwrite
    ) throws(FileError) {
        
        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        // MARK: TODO: On platforms that support renameat2, use that with RENAME_NOREPLACE flag instead of this manual check

        if targetExistOption != .overwrite {
            let itemExists = itemExists(at: dstPath)
            switch (itemExists, targetExistOption) {
                case (true, .skip): return 
                case (true, .error): throw FileError(code: .fileExists, operationDescription: .movingItem(from: srcPath, to: dstPath))!
                case (_, _): break
            }
        }

        try catchSystemError(operationDescription: .movingItem(from: srcPath, to: dstPath)) { () throws(SystemError) in
            try InternalFS.rename(itemAt: srcPath, to: dstPath)
        }

        #endif 

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

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        try catchSystemError(operationDescription: .creatingSymlink(at: path, pointingTo: destPath)) { () throws(SystemError) in
            try InternalFS.symlink(dstPath: destPath, linkPath: path)
        }

        #endif 

    }


    public func createHardLink(at path: FilePath, for existingPath: FilePath) throws(FileError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try catchSystemError(operationDescription: .creatingHardlink(at: path, for: existingPath)) { () throws(SystemError) in
            try InternalFS.link(existingPath: existingPath, newPath: path)
        }

        #endif 

    }


    public func destinationOfSymLink(at path: FilePath, recursive: Bool = true) throws(FileError) -> FilePath {
        
        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else

        try catchSystemError(operationDescription: .readingSymlink(at: path)) { () throws(SystemError) in
            if recursive {
                try InternalFS.realpath(of: path)
            } else {
                try InternalFS.readlink(fromSymlinkAt: path)
            }
        }

        #endif 

    }


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