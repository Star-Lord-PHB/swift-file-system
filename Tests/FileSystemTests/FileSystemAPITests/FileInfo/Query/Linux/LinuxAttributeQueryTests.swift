#if canImport(Glibc) || canImport(Musl)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileInfoAPITests.QueryTests {

    @Suite("Linux attributes")
    struct LinuxAttributeQueryTests {

        typealias Support = FileInfoAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileInfoAPITests.QueryTests.LinuxAttributeQueryTests {


    @Test
    func `Regular file attrs match statx`() throws {

        let path = try workspace.makeFile(at: "file")

        let info = try FileInfo(fileAt: path)
        let expected = try Support.ItemMetadata.captureAttributes(at: path)

        #expect(info.attributes == expected.values)
        #expect(info.supportedAttributes == expected.supported)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Directory attrs match statx`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let info = try FileInfo(fileAt: path)
        let expected = try Support.ItemMetadata.captureAttributes(at: path)

        #expect(info.attributes == expected.values)
        #expect(info.supportedAttributes == expected.supported)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Symlink attrs match no-follow statx`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let info = try FileInfo(fileAt: link, followSymLink: false)
        let expected = try Support.ItemMetadata.captureAttributes(at: link)

        #expect(info.attributes == expected.values)
        #expect(info.supportedAttributes == expected.supported)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }

}

#endif
