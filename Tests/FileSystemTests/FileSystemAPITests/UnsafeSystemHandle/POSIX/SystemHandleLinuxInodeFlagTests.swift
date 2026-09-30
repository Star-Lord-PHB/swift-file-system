#if os(Linux) || os(Android)

import PlatformCLib
import Testing
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.PosixTests {

    /// Opens an unconnected Unix domain stream socket.
    private func makeUnixSocket(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> UnsafeSystemHandle {
        #if canImport(Glibc)
        let socketType = Int32(SOCK_STREAM.rawValue)
        #else
        // Musl and Bionic define SOCK_STREAM as a plain integer macro.
        let socketType = SOCK_STREAM
        #endif
        let descriptor = socket(AF_UNIX, socketType, 0)
        try #require(
            descriptor >= 0,
            "socket failed with errno \(errno)",
            sourceLocation: sourceLocation
        )
        return UnsafeSystemHandle(owningRawHandle: descriptor)
    }


    @Test
    func `Inode flag query on a pipe reports unsupported`() throws {

        let handles = try UnsafeSystemHandle.pipe()

        let error = #expect(throws: LowLevelError.self) {
            _ = try handles.readHandle.inodeFlags()
        }

        #expect(error?.kind == .unsupported)
        #expect(error?.systemCode?.rawValue == ENOTTY)

    }


    @Test
    func `Inode flag set on a socket reports unsupported`() throws {

        // An owned socket cannot carry inode flags. This exercises the setter's ENOTTY path
        // without attempting to change metadata on an external filesystem. A pipe does not work
        // on Android: the kernel checks the SELinux setattr permission for FS_IOC_SETFLAGS before
        // the ioctl reaches the file, and Android's policy grants it on a process's own sockets
        // but never on its own pipes.
        let handle = try makeUnixSocket()

        let error = #expect(throws: LowLevelError.self) {
            try handle.setInodeFlags([.noDump])
        }

        #expect(error?.kind == .unsupported)
        #expect(error?.systemCode?.rawValue == ENOTTY)

    }


    @Test(arguments: [false, true])
    func `Inode flag operations preserve bad descriptor errors`(setFlags: Bool) throws {

        let path = try workspace.makeFile(at: "file")
        // O_PATH descriptors reject ioctl with EBADF. The descriptor stays open throughout
        // the test, so this does not risk reusing a descriptor closed behind its owner.
        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .none)
        )

        let error = #expect(throws: LowLevelError.self) {
            if setFlags {
                try handle.setInodeFlags([.noDump])
            } else {
                _ = try handle.inodeFlags()
            }
        }

        #expect(error?.kind == .invalidHandle)
        #expect(error?.systemCode == .badFileDescriptor)

    }

}

#endif
