import SystemPackage
import FileSystemCore


public protocol FileSystemProtocal: Sendable {

    // MARK: Basic Operations

    func itemExists(at path: FilePath, followSymlinks: Bool) -> Bool

    func createFile(at path: FilePath, replaceExisting: Bool, permissions: FilePermissions?, content: ByteBuffer?) throws(PlatformError)

    // note: the permission will only be applied to the leaf directory, not the intermediate directories
    func createDirectory(at path: FilePath, withIntermediateDirectories: Bool, permissions: FilePermissions?) throws(PlatformError)

    #if canImport(WinSDK)
    func createFile(at path: FilePath, replaceExisting: Bool, permissions: WindowsSecurityDescriptorView, content: ByteBuffer?) throws(PlatformError)

    func createDirectory(at path: FilePath, withIntermediateDirectories: Bool, permissions: WindowsSecurityDescriptorView) throws(PlatformError)
    #endif

    func removeItem(at path: FilePath) throws(PlatformError)

    func copyItem<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>(
        at srcPath: FilePath, 
        to dstPath: FilePath, 
        onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption, 
        symlinkOption: FileOperationOptions.CopyItemSymlinkOption,
        errorStrategy: ErrorStrategy
    ) throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.ReturnedError

    func moveItem(at srcPath: FilePath, to dstPath: FilePath, onExistingTarget targetExistOption: FileOperationOptions.CopyTargetExistOption) throws(PlatformError)

    func contentsOfDirectory(at path: FilePath, options: FileOperationOptions.DirectoryTraversalOption) throws(PlatformError) -> [DirectoryEntry]

    func createSymLink(at path: FilePath, pointingTo destPath: FilePath) throws(PlatformError)

    func createHardLink(at path: FilePath, for existingPath: FilePath) throws(PlatformError)

    func destinationOfSymLink(at path: FilePath, recursive: Bool) throws(PlatformError) -> FilePath


    // MARK: File Information Operations

    func info(ofItemAt path: FilePath, followSymlinks: Bool) throws(PlatformError) -> FileInfo

    func setTimes(
        forItemAt path: FilePath,
        accessTime: FileTimeSpec?,
        modificationTime: FileTimeSpec?,
        creationTime: FileTimeSpec?,
        followSymlink: Bool
    ) throws(PlatformError)

    
    func setAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes, followSymlink: Bool) throws(PlatformError)

    #if canImport(Glibc) || canImport(Musl)
    func getInodeFlags(forItemAt path: FilePath, followSymlink: Bool) throws(PlatformError) -> LinuxInodeFlags

    func setInodeFlags(forItemAt path: FilePath, flags: LinuxInodeFlags, followSymlink: Bool) throws(PlatformError)
    #endif


    // MARK: File Permission Operations

    func canAccess(itemAt path: FilePath, for accessMode: FileOperationOptions.FileAccessMode, followSymlink: Bool) throws(PlatformError) -> Bool

    #if canImport(WinSDK)
    func getSecurityInfo(
        forItemAt path: FilePath, 
        querying: FileOperationOptions.WindowsSecurityInfoMembers,
        followSymlink: Bool
    ) throws(PlatformError) -> WindowsSelfRelativeSecurityDescriptor
    
    func setSecurityInfo(
        forItemAt path: FilePath, 
        dacl: consuming FileOperationOptions.WindowsAclUpdateRequest, 
        sacl: consuming FileOperationOptions.WindowsAclUpdateRequest, 
        owner: PlatformIdentity?, 
        group: PlatformIdentity?,
        followSymlink: Bool
    ) throws(PlatformError)
    #else
    func getPosixPermissions(forItemAt path: FilePath, followSymlink: Bool) throws(PlatformError) -> FilePermissions
    
    func setPosixPermissions(forItemAt path: FilePath, permissions: FilePermissions, followSymlink: Bool) throws(PlatformError)
    #endif
    
    func getOwner(forItemAt path: FilePath, followSymlink: Bool) throws(PlatformError) -> (owner: PlatformIdentity, group: PlatformIdentity)
    
    func setOwner(forItemAt path: FilePath, owner: PlatformIdentity?, group: PlatformIdentity?, followSymlink: Bool) throws(PlatformError)


    // MARK: File Handles

    func withFileHandle<R: ~Copyable>(forReadingAt path: FilePath, options: FileOperationOptions.OpenForReading, body: (borrowing ReadFileHandle) throws -> R) throws -> R

    func withFileHandle<R: ~Copyable>(forWritingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (borrowing WriteFileHandle) throws -> R) throws -> R

    func withFileHandle<R: ~Copyable>(forAppendingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (borrowing AppendHandle) throws -> R) throws -> R

    func withFileHandle<R: ~Copyable>(forUpdatingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (borrowing ReadWriteFileHandle) throws -> R) throws -> R

    func withDirHandle<R: ~Copyable>(at path: FilePath, options: FileOperationOptions.OpenForDirectory, body: (borrowing DirectoryHandle) throws -> R) throws -> R


    // MARK: Common Paths and Directories
    
    func currentWorkingDirectoryPath() throws(PlatformError) -> FilePath

    func executablePath() throws(PlatformError) -> FilePath

    func homeDirectoryPath() throws(PlatformError) -> FilePath

    func tempDirectoryPath() throws(PlatformError) -> FilePath

    func cacheDirectoryPath() throws(PlatformError) -> FilePath

}



#if canImport(WinSDK)
extension FileSystemProtocal {

    public func createFile(
        at path: FilePath, 
        replaceExisting: Bool = false, 
        permissions: borrowing WindowsAbsoluteSecurityDescriptor, 
        content: ByteBuffer? = nil
    ) throws(PlatformError) {
        try createFile(at: path, replaceExisting: replaceExisting, permissions: permissions.view, content: content)
    }

    public func createFile(
        at path: FilePath, 
        replaceExisting: Bool = false, 
        permissions: borrowing WindowsSelfRelativeSecurityDescriptor, 
        content: ByteBuffer? = nil
    ) throws(PlatformError) {
        try createFile(at: path, replaceExisting: replaceExisting, permissions: permissions.view, content: content)
    }


    public func createDirectory(
        at path: FilePath, 
        withIntermediateDirectories: Bool = false, 
        permissions: borrowing WindowsAbsoluteSecurityDescriptor
    ) throws(PlatformError) {
        try createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, permissions: permissions.view)
    }

    public func createDirectory(
        at path: FilePath, 
        withIntermediateDirectories: Bool = false, 
        permissions: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) {
        try createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, permissions: permissions.view)
    }

}
#endif
