import SystemPackage


/// An entry of a directory.
public struct DirectoryEntry: Sendable, Equatable, Hashable {

    /// The path of the entry.
    /// 
    /// The path is usually a relative path to the directory being enumerated, but not a requirement.
    public var path: FilePath
    /// The type of the entry item.
    public var type: FileKind

    /// The filename of the entry.
    public var name: String {
        assert(path.lastComponent != nil, "Path of a directory entry must not be empty")
        return path.lastComponent!.string
    }

    /// Creates a directory entry with the given path and type.
    public init?(path: FilePath, type: FileKind) {
        guard path.lastComponent != nil else {
            return nil
        }
        self.path = path
        self.type = type
    }

}
