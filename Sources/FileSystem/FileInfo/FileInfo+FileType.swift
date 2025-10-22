import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
#endif


extension FileInfo {

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

}



extension FileInfo.FileType: CustomStringConvertible {

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
extension FileInfo.FileType {

    init(unsafeFromFileHandle fileHandle: HANDLE, attributes: DWORD) throws(SystemError) {

        let fileTypeFlags = GetFileType(fileHandle)
        try SystemError.check()

        var isSimLink: Bool {
            get throws(SystemError) {
                var fileAttributeTagInfo = _FILE_ATTRIBUTE_TAG_INFO()
                let structSize = DWORD(MemoryLayout<_FILE_ATTRIBUTE_TAG_INFO>.size)
                try execThrowingCFunction {
                    GetFileInformationByHandleEx(fileHandle, FileAttributeTagInfo, &fileAttributeTagInfo, structSize)
                }
                return fileAttributeTagInfo.ReparseTag == IO_REPARSE_TAG_SYMLINK
            }
        }

        var hasDirectoryFlag: Bool {
            return (attributes & .init(FILE_ATTRIBUTE_DIRECTORY)) != 0
        }

        self = switch fileTypeFlags {
            case .init(FILE_TYPE_DISK) where hasDirectoryFlag:  .directory
            case .init(FILE_TYPE_DISK) where try isSimLink:     .symlink
            case .init(FILE_TYPE_DISK):                         .regular
            case .init(FILE_TYPE_CHAR):                         .character
            case .init(FILE_TYPE_PIPE):                         .fifo
            default:                                            .unknown
        }

    }

}
#else
extension FileInfo.FileType {

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


    public init(d_type: UInt8) {
        self = switch d_type {
            case .init(DT_REG):     .regular
            case .init(DT_DIR):     .directory
            case .init(DT_LNK):     .symlink
            case .init(DT_SOCK):    .socket
            case .init(DT_BLK):     .block
            case .init(DT_CHR):     .character
            case .init(DT_FIFO):    .fifo
            default:                .unknown
        }
    }

}
#endif