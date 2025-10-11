import Foundation
import SystemPackage


extension FileInfo {

    public enum FileType {
        case regular
        case directory
        case symlink
        case socket
        case block
        case character
        case fifo
        case unknown

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

}