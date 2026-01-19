import PlatformCLib
import SystemPackage


public enum FileType: Sendable, Equatable, Hashable {
    case regular
    case directory
    case symlink
    case socket
    case block
    case character
    case fifo
    case unknown
}



extension FileType: CustomStringConvertible {

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



#if !canImport(WinSDK)
extension FileType {

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