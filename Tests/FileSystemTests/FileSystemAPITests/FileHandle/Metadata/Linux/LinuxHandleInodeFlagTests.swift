#if canImport(Glibc) || canImport(Musl)

import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Linux inode flags")
    struct LinuxInodeFlagTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.LinuxInodeFlagTests {

    @Test
    func `Flag query matches ioctl`() throws {

        let path = try workspace.makeFile(at: "file")
        let preparedFlags = try Support.captureNativeInodeFlags(at: path).union(.noDump)
        try Support.setNativeInodeFlags(preparedFlags, at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let actual = try handle.inodeFlags()
        let expected = try Support.captureNativeInodeFlags(at: path)

        #expect(actual == expected)
        #expect(actual.contains(.noDump))

        try handle.close()

    }


    @Test
    func `Sets inode flags`() throws {

        let path = try workspace.makeFile(at: "file")
        let requestedFlags = try Support.captureNativeInodeFlags(at: path).union(.noDump)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setInodeFlags(requestedFlags)

        try handle.close()

        #expect(try Support.captureNativeInodeFlags(at: path) == requestedFlags)

    }


    @Test
    func `Clearing noDump preserves existing flags`() throws {

        let path = try workspace.makeFile(at: "file")
        let flagsBeforeSet = try Support.captureNativeInodeFlags(at: path)
        try Support.setNativeInodeFlags(flagsBeforeSet.union(.noDump), at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setInodeFlags(flagsBeforeSet)

        try handle.close()

        #expect(try Support.captureNativeInodeFlags(at: path) == flagsBeforeSet)

    }

}

#endif
