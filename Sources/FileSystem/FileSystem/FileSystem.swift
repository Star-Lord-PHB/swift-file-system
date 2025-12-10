import SystemPackage
import PlatformCLib
import CFileSystem


public final class FileSystem: FileSystemProtocal {

    public init() {}


    public func info(ofFileAt path: FilePath, followSymlinks: Bool = false) throws(FileError) -> FileInfo {
        return try .init(fileAt: path, followSymLink: followSymlinks)
    }


    public func itemExists(at path: FilePath, followSymlinks: Bool = false) -> Bool {

        #if canImport(WinSDK)

        if followSymlinks {
            var st = stat()
            return path.withPlatformString { platformStr in
                stat(platformStr, &st) == 0
            }
        } else {
            return GetFileAttributesW(path.string.wideCString) != INVALID_FILE_ATTRIBUTES
        }

        #else
        
        var st = stat()
        if followSymlinks {
            return stat(path.string, &st) == 0
        } else {
            return lstat(path.string, &st) == 0
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
                try _createDirectoryNoIntermediate(at: path)
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
                try _createDirectoryNoIntermediate(at: path)
            }
        }

    }


    public func removeItem(at path: FilePath) throws(FileError) {

        #if canImport(WinSDK)
        try execThrowingCFunction(operationDescription: .removingItem(at: path)) {
            path.withPlatformString { platformStr in 
                DeleteFileW(platformStr)
            }
        }
        #else 
        if remove(path.string) == 0 { return }
        guard errno == ENOTEMPTY else {
            try FileError.assertError(operationDescription: .removingItem(at: path))
        }
        try catchSystemError(operationDescription: .removingItem(at: path)) { () throws(SystemError) in
            try _removeDirectoryRecursive(at: path)
        }
        #endif 

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
            symlinkOption == .copyTarget ? try _symlinkRecursiveDestination(of: srcPath) : srcPath
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
                case (true, .error): throw FileError(code: .fileExists, operationDescription: .movingItem(from: srcPath, to: dstPath))
                case (_, _): break
            }
        }

        try execThrowingCFunction(operationDescription: .movingItem(from: srcPath, to: dstPath)) {
            rename(srcPath.string, dstPath.string)
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

        try execThrowingCFunction(operationDescription: .creatingSymlink(at: path, pointingTo: destPath)) {
            symlink(destPath.string, path.string)
        }

        #endif 

    }


    public func createHardLink(at path: FilePath, for existingPath: FilePath) throws(FileError) {

        #if canImport(WinSDK)

        #warning("Not implemented")
        fatalError("Not implemented")

        #else 

        try execThrowingCFunction(operationDescription: .creatingHardlink(at: path, for: existingPath)) {
            linkat(AT_FDCWD, existingPath.string, AT_FDCWD, path.string, 0)
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
                try _symlinkRecursiveDestination(of: path)
            } else {
                try _symlinkDirectDestination(of: path)
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