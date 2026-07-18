import SystemPackage


public struct DirectoryEntry: Sendable, Equatable, Hashable {

    public var path: FilePath
    public var type: FileKind

    public var name: String {
        assert(path.lastComponent != nil, "Path of a directory entry must not be empty")
        return path.lastComponent!.string
    }

    public init?(path: FilePath, type: FileKind) {
        guard path.lastComponent != nil else {
            return nil
        }
        self.path = path
        self.type = type
    }

}
