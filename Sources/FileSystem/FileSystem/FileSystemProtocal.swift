import SystemPackage


public protocol FileSystemProtocal: Sendable {

    init()


    // MARK: Basic Operations

    func info(ofFileAt path: FilePath, followSymlinks: Bool) throws(FileError) -> FileInfo

    func itemExists(at path: FilePath, followSymlinks: Bool) -> Bool

    func createFile(at path: FilePath, replaceExisting: Bool, permission: FilePermissions?, content: ByteBuffer?) throws(FileError)

    func createDirectory(at path: FilePath, withIntermediateDirectories: Bool) throws(FileError)

    func removeItem(at path: FilePath) throws(FileError)

    func copyItem(
        at srcPath: FilePath, 
        to dstPath: FilePath, 
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption,
        symlinkOption: FileOperationOptions.CopyItemSymlinkOption
    ) throws(FileError)

    func moveItem(at srcPath: FilePath, to dstPath: FilePath, onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption) throws(FileError)

    func contentsOfDirectory(at path: FilePath, options: FileOperationOptions.DirectoryTraversalOption) throws(FileError) -> [DirectoryEntry]

    func createSymLink(at path: FilePath, pointingTo destPath: FilePath) throws(FileError)

    func createHardLink(at path: FilePath, for existingPath: FilePath) throws(FileError)

    func destinationOfSymLink(at path: FilePath, recursive: Bool) throws(FileError) -> FilePath

    // MARK: TODO: Add APIs for updating file information


    // MARK: File Handles

    func withFileHandle<R: ~Copyable>(forReadingAt path: FilePath, options: FileOperationOptions.OpenForReading, body: (borrowing ReadFileHandle) throws -> R) throws -> R

    func withFileHandle<R: ~Copyable>(forWritingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (borrowing WriteFileHandle) throws -> R) throws -> R

    func withFileHandle<R: ~Copyable>(forUpdatingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (borrowing ReadWriteFileHandle) throws -> R) throws -> R

    func withDirHandle<R: ~Copyable>(at path: FilePath, options: FileOperationOptions.OpenForDirectory, body: (borrowing DirectoryHandle) throws -> R) throws -> R

}