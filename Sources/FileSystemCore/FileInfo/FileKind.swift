import PlatformCLib
import SystemPackage


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
    public static func isNameSurrogateReparseTag(_ tag: DWORD) -> Bool {
        tag & 0x2000_0000 != 0
    }


    /// Classifies a Windows item from its file attributes and reparse tag.
    ///
    /// Symlinks map to ``symlink``; any other name-surrogate reparse point (junctions and
    /// volume mount points) is not modeled by this library and maps to ``unknown``;
    /// non-surrogate reparse points fall through to their underlying kind.
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
