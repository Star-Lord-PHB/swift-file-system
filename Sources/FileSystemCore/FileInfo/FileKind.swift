import PlatformCLib
import SystemPackage


/// The type of a file
public enum FileKind: Sendable, Equatable, Hashable {
    case regular
    case directory
    case symlink
    case socket
    case block
    case character
    case fifo
    case unknown
}



extension FileKind: CustomStringConvertible {

    @inlinable
    public var description: String {
        switch self {
            case .regular:      "regular file"
            case .directory:    "directory"
            case .symlink:      "symbolic link"
            case .socket:       "socket"
            case .block:        "block device"
            case .character:    "character device"
            case .fifo:         "fifo"
            case .unknown:      "unknown"
        }
    }

}



#if canImport(WinSDK)
extension FileKind {

    /// Whether a Windows reparse tag has name-surrogate semantics — the object stands for
    /// another named entity in the system. Symlinks and junctions / volume mount points are
    /// name surrogates; other reparse points (cloud placeholders, app-exec links,
    /// deduplicated files) behave as their underlying kind.
    @inlinable
    package static func isNameSurrogateReparseTag(_ tag: DWORD) -> Bool {
        tag & 0x2000_0000 != 0
    }


    /// Create the file kind from the Windows native file attributes and reparse tag.
    ///
    /// Symlinks are map to ``FileKind/symlink`` while any other name-surrogate reparse point (junctions and 
    /// volume mount points) is maps to ``FileKind/unknown``. Non-surrogate reparse points fall through to 
    /// their underlying kind.
    @inlinable
    public init(windowsFileAttributes attributes: DWORD, reparseTag: DWORD) {
        self = if attributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0,
            Self.isNameSurrogateReparseTag(reparseTag) {
            reparseTag == IO_REPARSE_TAG_SYMLINK ? .symlink : .unknown
        } else if attributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0 {
            .directory
        } else {
            .regular
        }
    }

}
#endif



#if !canImport(WinSDK)
extension FileKind {

    /// Create the file kind from a POSIX mode value.
    @inlinable
    public init(mode: mode_t) {
        self = switch mode & S_IFMT {
            case S_IFREG: .regular
            case S_IFDIR: .directory
            case S_IFLNK: .symlink
            case S_IFSOCK: .socket
            case S_IFBLK: .block
            case S_IFCHR: .character
            case S_IFIFO: .fifo
            default: .unknown
        }
    }

}
#endif
