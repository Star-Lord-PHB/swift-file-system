#if canImport(WinSDK)

import Foundation
import SystemPackage
import Testing
import WinSDK



extension FileSystemTestSupport {

    /// Creates a junction (mount-point reparse point) — a name-surrogate reparse point that
    /// is not a symlink, which the library deliberately does not model.
    static func makeWindowsJunction(
        at linkPath: FilePath,
        pointingTo target: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {

        try #require(
            linkPath.withPlatformString { CreateDirectoryW($0, nil) },
            sourceLocation: sourceLocation
        )
        let handle = linkPath.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(GENERIC_WRITE),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_FLAG_BACKUP_SEMANTICS) | DWORD(FILE_FLAG_OPEN_REPARSE_POINT),
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }

        let substituteName = Array("\\??\\\(target.string)".utf16)
        let printName = Array(target.string.utf16)
        let pathBufferBytes = (substituteName.count + 1 + printName.count + 1) * 2

        var buffer = Data()
        func append16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { buffer.append(contentsOf: $0) }
        }
        withUnsafeBytes(of: UInt32(0xA000_0003).littleEndian) {    // IO_REPARSE_TAG_MOUNT_POINT
            buffer.append(contentsOf: $0)
        }
        append16(UInt16(8 + pathBufferBytes))                      // ReparseDataLength
        append16(0)                                                // Reserved
        append16(0)                                                // SubstituteNameOffset
        append16(UInt16(substituteName.count * 2))                 // SubstituteNameLength
        append16(UInt16((substituteName.count + 1) * 2))           // PrintNameOffset
        append16(UInt16(printName.count * 2))                      // PrintNameLength
        for unit in substituteName { append16(unit) }
        append16(0)
        for unit in printName { append16(unit) }
        append16(0)

        var bytesReturned = DWORD(0)
        let fsctlSetReparsePoint = DWORD(0x000900A4)
        try #require(
            buffer.withUnsafeBytes { rawBuffer in
                DeviceIoControl(
                    handle,
                    fsctlSetReparsePoint,
                    UnsafeMutableRawPointer(mutating: rawBuffer.baseAddress),
                    DWORD(rawBuffer.count),
                    nil,
                    0,
                    &bytesReturned,
                    nil
                )
            },
            sourceLocation: sourceLocation
        )

    }

}

#endif
