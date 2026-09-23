import PlatformCLib
import SystemPackage
import CFileSystem



/// Metadata of a file
public struct FileInfo: Sendable, Equatable, Hashable {

    /// The size of the file in bytes
    public let size: UInt64

    /// The type of the file
    public let type: FileKind

    /// The access / modification / change / creation times of the file
    public let times: FileTimes

    /// The unique identifier of the file (include the device identifier)
    public let fileIdentifier: FileIdentifier

    /// The attributes (flags) of the file
    public let attributes: PlatformFileAttributes
    /// The attributes (flags) that are actually supported by this file.
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
