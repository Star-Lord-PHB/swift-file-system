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
    public var name: FilePath.Component {
        assert(path.lastComponent != nil, "Path of a directory entry must not be empty")
        return path.lastComponent!
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



/// Element type of a recursive directory sequence.
public enum DirectoryEntryRecursiveSequenceElement: Sendable {
    /// A normal directory entry.
    case entry(DirectoryEntry)
    /// Leaving a directory, with an optional associated error if leaving a dir early due to an error or leaving itself caused an error
    case leavingDir(FilePath, PlatformError?)
    /// An error occurred when reading a directory entry.
    case entryError(FilePath, PlatformError)
    /// An error occurred when getting into a subdirectory (nothing inside this directory will be traversed)
    case subTreeError(FilePath, PlatformError)

    /// The path of the current entry.
    public var path: FilePath {
        switch self {
            case .entry(let entry):          entry.path
            case .leavingDir(let path, _):   path
            case .entryError(let path, _):   path
            case .subTreeError(let path, _): path
        }
    }

    /// The name of the current entry.
    /// 
    /// Same as `path.lastComponent!`
    public var name: FilePath.Component { path.lastComponent! }

    /// The error associated with the current entry, if any.
    public var error: PlatformError? {
        switch self {
            case .entry:                     return nil
            case .leavingDir(_, let err):    return err
            case .entryError(_, let err):    return err
            case .subTreeError(_, let err):  return err
        }
    }
}
