import SystemPackage


public struct DirectoryEntry: Sendable, Equatable, Hashable {

    public var path: FilePath
    public var type: FileInfo.FileType

    public var name: String {
        assert(path.lastComponent != nil, "Path of a directory entry must not be empty")
        return path.lastComponent!.string
    }

    public init?(path: FilePath, type: FileInfo.FileType) {
        guard path.lastComponent != nil else {
            return nil
        }
        self.path = path
        self.type = type
    }

}