import SystemPackage


public protocol FileSystemProtocal: Sendable {

    init()


    // MARK: Basic Operations

    func info(ofFileAt path: FilePath, followSymlinks: Bool) throws(FileError) -> FileInfo

    func itemExists(at path: FilePath, followSymlinks: Bool) -> Bool

    func createFile(at path: FilePath, replaceExisting: Bool) throws(FileError)

    func createDirectory(at path: FilePath, withIntermediateDirectories: Bool) throws(FileError)

    func removeItem(at path: FilePath) throws(FileError)

    func copyItem(at srcPath: FilePath, to dstPath: FilePath) throws(FileError)

    func moveItem(at srcPath: FilePath, to dstPath: FilePath) throws(FileError)

    func contentsOfDirectory(at path: FilePath) throws(FileError) -> [FilePath]

    func createSymLink(at path: FilePath, pointingTo destPath: FilePath) throws(FileError)

    func destinationOfSymLink(at path: FilePath) throws(FileError) -> FilePath


    // MARK: File Handles

    func withFileHandle<R>(forReadingAt path: FilePath, body: (consuming ReadFileHandle) throws -> R) throws(FileError)

    func withFileHandle<R>(forWritingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (consuming WriteFileHandle) throws -> R) throws(FileError)

    func withFileHandle<R>(forUpdatingAt path: FilePath, option: FileOperationOptions.OpenForWriting, body: (consuming ReadWriteFileHandle) throws -> R) throws(FileError)

}