//
//  StreamingOpen.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/26.
//

import struct SystemPackage.FilePath
import FileSystemCore



// The shared open path of the three streaming handles. They connect to an existing endpoint
// and never wait for a peer: POSIX opens with O_NONBLOCK so a FIFO open cannot block and
// restores blocking mode right after for the actual I/O; a Windows CreateFile never waits for
// a peer on its own (a named-pipe client fails fast when no instance is available). O_NOCTTY
// keeps an opened terminal from becoming the controlling terminal as a side effect.
enum StreamingOpen {

    static func open(
        at path: FilePath,
        access: UnsafeSystemHandle.OpenOptions.AccessMode,
        options: FileOperationOptions.OpenForStreaming
    ) throws(PlatformError) -> UnsafeSystemHandle {

        let openOptions = UnsafeSystemHandle.OpenOptions(
            access: access,
            noFollow: options.noFollow,
            closeOnExec: options.closeOnExec,
            platformOpenFlagsDiff: .inserted([.posix.nonBlocking, .posix.noCtty])
        )

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.open(at: path, openOptions: openOptions)
        } kindConversion: { error in
            switch error.systemCode {
                #if canImport(WinSDK)
                case .accessDenied: .windows.permissionDeniedOrIsADirectory
                case .pipeBusy: .peerUnavailable
                #else
                case .noSuchDeviceOrAddress: .peerUnavailable
                #endif
                default: error.kind
            }
        }

        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            switch try handle.type() {
                case .symlink: throw .init(kind: .pathResolutionFailed)
                case .directory: throw .init(kind: .isADirectory)
                default: break
            }
        }

        #if !canImport(WinSDK)
        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try handle.setNonBlocking(false)
            #if canImport(Darwin) || os(FreeBSD)
            // A torn-down peer should surface as a brokenPipe error instead of raising
            // SIGPIPE; Linux and OpenBSD have no per-descriptor equivalent, so there the
            // process itself has to deal with SIGPIPE.
            try handle.withUnsafeRawHandle { fd throws(LowLevelError) in
                try execThrowingCFunction {
                    fcntl(fd, F_SETNOSIGPIPE, 1)
                }
            }
            #endif
        }
        #endif

        return handle

    }

}
