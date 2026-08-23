#if canImport(Glibc) || canImport(Musl)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileSystemTestSupport {

    static func captureNativeInodeFlags(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> LinuxInodeFlags {
        let descriptor = path.withPlatformString { pathPointer in
            open(pathPointer, O_RDONLY | O_CLOEXEC)
        }
        try #require(descriptor >= 0, sourceLocation: sourceLocation)
        defer { close(descriptor) }

        var rawFlags: PlatformInteropTypes.PosixInodeFlags = 0
        let result = ioctl(descriptor, _FS_IOC_GETFLAGS, &rawFlags)
        try #require(result == 0, sourceLocation: sourceLocation)
        return .init(rawValue: rawFlags)
    }


    static func setNativeInodeFlags(
        _ flags: LinuxInodeFlags,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let descriptor = path.withPlatformString { pathPointer in
            open(pathPointer, O_RDONLY | O_CLOEXEC)
        }
        try #require(descriptor >= 0, sourceLocation: sourceLocation)
        defer { close(descriptor) }

        var rawFlags = flags.rawValue
        let result = ioctl(descriptor, _FS_IOC_SETFLAGS, &rawFlags)
        try #require(result == 0, sourceLocation: sourceLocation)
    }

}

#endif
