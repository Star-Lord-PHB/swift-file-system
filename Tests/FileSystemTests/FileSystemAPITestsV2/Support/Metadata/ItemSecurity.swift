import SystemPackage
import Testing
import SwiftFileSystem

#if canImport(WinSDK)
import WinSDK
#endif



extension FileSystemTestSupport.ItemMetadata {

    struct Security: Equatable, Sendable {

        #if canImport(WinSDK)
        let windowsSnapshot: FileSystemTestSupport.WindowsSecuritySnapshot

        var ownership: Ownership {
            .init(
                owner: .init(
                    rawId: windowsSnapshot.owner!,
                    platformKind: .user
                ),
                group: .init(
                    rawId: windowsSnapshot.group!,
                    platformKind: .group
                )
            )
        }

        var permissions: Permissions {
            let control = DWORD(windowsSnapshot.control)
            return .init(
                dacl: windowsSnapshot.dacl,
                isProtected: control & DWORD(SE_DACL_PROTECTED) != 0,
                isAutoInheritanceRequested:
                    control & DWORD(SE_DACL_AUTO_INHERIT_REQ) != 0,
                isAutoInherited:
                    control & DWORD(SE_DACL_AUTO_INHERITED) != 0
            )
        }
        #else
        let ownership: Ownership
        let permissions: Permissions
        #endif

        var owner: PlatformIdentity { ownership.owner }
        var group: PlatformIdentity { ownership.group }

    }


    static func captureSecurity(
        at path: FilePath,
        followSymlink: Bool = false,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Security {
        #if canImport(WinSDK)
        try captureWindowsSecurity(
            at: path,
            followSymlink: followSymlink,
            sourceLocation: sourceLocation
        )
        #else
        try capturePOSIXSecurity(at: path, followSymlink: followSymlink)
        #endif
    }

}



extension FileSystemTestSupport.ItemMetadata.Security {

    struct Ownership: Equatable, Sendable {

        let owner: PlatformIdentity
        let group: PlatformIdentity

    }

}



#if !canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata.Security {

    typealias Permissions = FilePermissions

}



extension FileSystemTestSupport.ItemMetadata {

    private static func capturePOSIXSecurity(
        at path: FilePath,
        followSymlink: Bool
    ) throws -> Security {
        let metadata = try Stat(
            path,
            followTargetSymlink: followSymlink
        )

        return .init(
            ownership: .init(
                owner: .init(
                    rawId: metadata.userID.rawValue,
                    platformKind: .user
                ),
                group: .init(
                    rawId: metadata.groupID.rawValue,
                    platformKind: .group
                )
            ),
            permissions: metadata.permissions
        )
    }

}
#endif



#if canImport(WinSDK)
extension FileSystemTestSupport.ItemMetadata.Security {

    struct Permissions: Equatable, Sendable {

        let dacl: FileSystemTestSupport.WindowsAclSnapshot
        let isProtected: Bool
        let isAutoInheritanceRequested: Bool
        let isAutoInherited: Bool

    }

}



extension FileSystemTestSupport.ItemMetadata {

    private static func captureWindowsSecurity(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation
    ) throws -> Security {
        let snapshot = try FileSystemTestSupport.captureWindowsSecuritySnapshot(
            at: path,
            querying: .allExceptSacl,
            followSymlink: followSymlink,
            sourceLocation: sourceLocation
        )
        _ = try #require(snapshot.owner, sourceLocation: sourceLocation)
        _ = try #require(snapshot.group, sourceLocation: sourceLocation)
        return .init(windowsSnapshot: snapshot)
    }


}
#endif
