#if canImport(Glibc) || canImport(Musl)

import PlatformCLib
import Testing
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.PosixTests {

    @Test
    func `Inode flag query on a pipe reports unsupported`() throws {

        let handles = try UnsafeSystemHandle.pipe()

        let error = #expect(throws: LowLevelError.self) {
            _ = try handles.readHandle.fileInodeFlags()
        }

        #expect(error?.kind == .unsupported)
        #expect(error?.systemCode?.rawValue == ENOTTY)

    }


    @Test
    func `Inode flag set on a pipe reports unsupported`() throws {

        // An owned anonymous pipe cannot carry inode flags. This exercises the setter's
        // ENOTTY path without attempting to change metadata on an external filesystem.
        let handles = try UnsafeSystemHandle.pipe()

        let error = #expect(throws: LowLevelError.self) {
            try handles.writeHandle.setFileInodeFlags([.noDump])
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
                try handle.setFileInodeFlags([.noDump])
            } else {
                _ = try handle.fileInodeFlags()
            }
        }

        #expect(error?.kind == .invalidHandle)
        #expect(error?.systemCode == .badFileDescriptor)

    }

}

#endif
