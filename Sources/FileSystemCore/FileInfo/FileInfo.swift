import PlatformCLib
import SystemPackage
import CFileSystem



public struct FileInfo: Sendable, Equatable, Hashable {

    public let size: UInt64

    public let type: FileType

    public let times: FileTimes

    public let fileIdentifier: FileIdentifier

    public let attributes: PlatformFileAttributes
    public let supportedAttributes: PlatformFileAttributes

}



extension FileInfo: CustomStringConvertible {

    @inlinable
    public var description: String {
        """
        File(\
        type: \(type), size: \(size) bytes, \
        last accessed: \(times.lastAccess), \
        last modified: \(times.lastModification), \
        last status changed: \(times.lastChange), \
        \(times.creation.map { "created: \($0)," } ?? "") \
        attributes: \(attributes))
        """
    }

}



extension FileInfo {

    #if !canImport(WinSDK)
    package init(stat: PlatformInteropTypes.Stat) {
        self.type = .init(mode: stat.st_mode)
        self.size = .init(stat.st_size)
        self.fileIdentifier = .init(fileId: stat.st_ino, deviceId: stat.st_dev)

        self.times = .init(
            lastAccess: .init(platformFileTime: stat.st_atim), 
            lastModification: .init(platformFileTime: stat.st_mtim), 
            lastChange: .init(platformFileTime: stat.st_ctim), 
            creation: stat.st_btim.map { .init(platformFileTime: $0) }
        )

        self.attributes = .init(rawValue: stat.st_flags)

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        self.supportedAttributes = .all
        #else 
        self.supportedAttributes = .init(rawValue: stat.st_flags_mask)
        #endif
    }
    #endif

}
