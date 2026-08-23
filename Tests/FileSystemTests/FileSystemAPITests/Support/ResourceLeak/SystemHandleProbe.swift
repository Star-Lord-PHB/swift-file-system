import Testing
import SwiftFileSystem

#if canImport(WinSDK)
import WinSDK
#else
import PlatformCLib
#endif



/// Captures the raw platform handle backing an open file handle so a test can later
/// verify that the underlying system handle has been released.
///
/// The probe re-queries the captured raw value: a failing query proves the handle was
/// closed, and a succeeding query is compared against the captured file identity so a
/// raw value recycled by an unrelated open (which is expected under parallel test
/// execution) still counts as released.
extension FileSystemTestSupport {

    struct SystemHandleProbe {

        private let rawHandle: UnsafeSystemHandle.SystemHandleType
        private let identity: Identity


        init(
            capturing systemHandle: borrowing UnsafeSystemHandle,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws {
            rawHandle = systemHandle.unsafeRawHandle
            identity = try #require(
                Self.queryIdentity(of: rawHandle),
                "The probed handle must be open when captured",
                sourceLocation: sourceLocation
            )
        }


        var isReleased: Bool {
            Self.queryIdentity(of: rawHandle) != identity
        }

    }

}



extension FileSystemTestSupport.SystemHandleProbe {

    #if canImport(WinSDK)

    private struct Identity: Equatable {
        let volumeSerialNumber: DWORD
        let fileIndexHigh: DWORD
        let fileIndexLow: DWORD
    }


    private static func queryIdentity(
        of rawHandle: UnsafeSystemHandle.SystemHandleType
    ) -> Identity? {
        var information = BY_HANDLE_FILE_INFORMATION()
        guard GetFileInformationByHandle(rawHandle, &information) else { return nil }
        return .init(
            volumeSerialNumber: information.dwVolumeSerialNumber,
            fileIndexHigh: information.nFileIndexHigh,
            fileIndexLow: information.nFileIndexLow
        )
    }

    #else

    private struct Identity: Equatable {
        let device: dev_t
        let inode: ino_t
    }


    private static func queryIdentity(
        of rawHandle: UnsafeSystemHandle.SystemHandleType
    ) -> Identity? {
        var status = stat()
        guard fstat(rawHandle, &status) == 0 else { return nil }
        return .init(device: status.st_dev, inode: status.st_ino)
    }

    #endif

}
