import SystemPackage
import FileSystemCore


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
        forAppendingAt path: FilePath,
        option: FileOperationOptions.OpenForWriting,
        body: (borrowing AppendHandle) throws -> R
    ) throws -> R {

        let handle = try AppendHandle(forFileAt: path, options: option)

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
