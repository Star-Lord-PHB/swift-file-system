import SystemPackage
import FileSystemCore


public protocol FileSystemProtocal: Sendable {

    init()


    // MARK: Basic Operations

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


    // File Information Operations

    func info(ofFileAt path: FilePath, followSymlinks: Bool) throws(FileError) -> FileInfo

    func setTimes(forItemAt path: FilePath, accessTime: FileTimeSpec?, modificationTime: FileTimeSpec?, creationTime: FileTimeSpec?) throws(FileError)

    
    func setAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes) throws(FileError)

    #if canImport(Glibc) || canImport(Musl)
    func getInodeFlags(forItemAt path: FilePath) throws(FileError) -> CInt

    func setInodeFlags(forItemAt path: FilePath, flags: CInt) throws(FileError)
    #endif 

    func setPermissions(forItemAt path: FilePath, permissions: FilePermissions) throws(FileError)

    func setOwner(forItemAt path: FilePath, owner: PlatformIdentity?, group: PlatformIdentity?) throws(FileError)

    #if canImport(WinSDK)
    func getSecurityInfo(
        forItemAt path: FilePath, 
        querying: FileOperationOptions.WindowsSecurityInfoMembers
    ) throws(FileError) -> WindowsSelfRelativeSecurityDescriptor
    
    func setSecurityInfo(
        forItemAt path: FilePath, 
        dacl: consuming FileOperationOptions.WindowsAclUpdateRequest, 
        sacl: consuming FileOperationOptions.WindowsAclUpdateRequest, 
        owner: PlatformIdentity?, 
        group: PlatformIdentity?
    ) throws(FileError)
    #endif 


    // MARK: File Handles

    func withFileHandle<R: ~Copyable>(forReadingAt path: FilePath, options: FileOperationOptions.OpenForReading, body: (borrowing ReadFileHandle) throws -> R) throws -> R

    func withFileHandle<R: ~Copyable>(forWritingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (borrowing WriteFileHandle) throws -> R) throws -> R

    func withFileHandle<R: ~Copyable>(forUpdatingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (borrowing ReadWriteFileHandle) throws -> R) throws -> R

    func withDirHandle<R: ~Copyable>(at path: FilePath, options: FileOperationOptions.OpenForDirectory, body: (borrowing DirectoryHandle) throws -> R) throws -> R


    // MARK: Common Paths and Directories
    func currentWorkingDirectoryPath() throws(FileError) -> FilePath

    func executablePath() throws(FileError) -> FilePath

    func homeDirectoryPath() throws(FileError) -> FilePath

    func tempDirectoryPath() throws(FileError) -> FilePath

    func cacheDirectoryPath() throws(FileError) -> FilePath

}