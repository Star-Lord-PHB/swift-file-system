#if canImport(Glibc) || canImport(Musl)

import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Linux attributes")
    struct LinuxAttributeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.LinuxAttributeTests {

    @Test
    func `Attribute query matches native flags`() throws {

        let path = try workspace.makeFile(at: "file")
        let preparedFlags = try Support.captureNativeInodeFlags(at: path).union(.noDump)
        try Support.setNativeInodeFlags(preparedFlags, at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let actual = try handle.fileAttributes()
        let expected = try Support.ItemMetadata.captureAttributes(at: path).values

        #expect(actual == expected)
        #expect(actual.contains(.linux.noDump))

        try handle.close()

    }


    @Test
    func `Sets noDump attribute`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileAttributes([.linux.noDump])

        try handle.close()

        #expect(try Support.ItemMetadata.captureAttributes(at: path).values.contains(.linux.noDump))

    }


    @Test
    func `Clearing noDump preserves other attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        let flagsBeforeSet = try Support.captureNativeInodeFlags(at: path)
        try Support.setNativeInodeFlags(flagsBeforeSet.union(.noDump), at: path)
        var requestedAttributes = try Support.ItemMetadata.captureAttributes(at: path).values
        try #require(requestedAttributes.remove(.linux.noDump) != nil)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileAttributes(requestedAttributes)

        try handle.close()

        #expect(try Support.ItemMetadata.captureAttributes(at: path).values == requestedAttributes)

    }

}

#endif
