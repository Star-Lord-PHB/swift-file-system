import SystemPackage
import Testing
import SwiftFileSystem

#if canImport(WinSDK)
import WinSDK
#endif



extension FileSystemTestSupport.ItemMetadata {

    static func captureIdentifier(
        at path: FilePath,
        followSymlink: Bool = false,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> FileIdentifier {
        #if canImport(WinSDK)
        try captureWindowsIdentifier(
            at: path,
            followSymlink: followSymlink,
            sourceLocation: sourceLocation
        )
        #else
        let metadata = try Stat(
            path,
            followTargetSymlink: followSymlink
        )
        return .init(
            fileId: UInt64(metadata.inode.rawValue),
            deviceId: UInt32(truncatingIfNeeded: metadata.deviceID.rawValue)
        )
        #endif
    }

}



#if canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata {

    private static func captureWindowsIdentifier(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation
    ) throws -> FileIdentifier {
        let noFollowFlag = followSymlink
            ? DWORD(0)
            : DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        let openFlags = DWORD(FILE_FLAG_BACKUP_SEMANTICS) | noFollowFlag
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(FILE_READ_ATTRIBUTES),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                openFlags,
                nil
            )
        }
        try #require(
            handle != INVALID_HANDLE_VALUE,
            sourceLocation: sourceLocation
        )
        defer { CloseHandle(handle) }

        var identifierInfo = FILE_ID_INFO()
        try #require(
            GetFileInformationByHandleEx(
                handle,
                FileIdInfo,
                &identifierInfo,
                DWORD(MemoryLayout<FILE_ID_INFO>.size)
            ),
            sourceLocation: sourceLocation
        )

        return .init(
            fileId: identifierInfo.FileId.uint128,
            deviceId: identifierInfo.VolumeSerialNumber
        )
    }

}
#endif
