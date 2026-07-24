#if !canImport(WinSDK)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileInfoAPITests.QueryTests {

    @Suite("POSIX fields")
    struct POSIXQueryTests {

        typealias Support = FileInfoAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileInfoAPITests.QueryTests.POSIXQueryTests {

    @Test
    func `Regular file identifier matches stat`() throws {

        let path = try workspace.makeFile(at: "file")

        let info = try FileInfo(fileAt: path)
        let expected = try Support.ItemMetadata.captureIdentifier(at: path)

        #expect(info.fileIdentifier == expected)

    }


    @Test
    func `Directory identifier matches stat`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let info = try FileInfo(fileAt: path)
        let expected = try Support.ItemMetadata.captureIdentifier(at: path)

        #expect(info.fileIdentifier == expected)

    }


    @Test
    func `Symlink identifiers match stat and lstat`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let followedInfo = try FileInfo(fileAt: link, followSymLink: true)
        let directInfo = try FileInfo(fileAt: link, followSymLink: false)
        let followedExpected = try Support.ItemMetadata.captureIdentifier(at: target)
        let directExpected = try Support.ItemMetadata.captureIdentifier(at: link)

        #expect(followedInfo.fileIdentifier == followedExpected)
        #expect(directInfo.fileIdentifier == directExpected)

    }


    #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    @Test
    func `File attrs match BSD stat flags`() throws {

        let path = try workspace.makeFile(at: "file")
        // Explicitly use a nonzero flag instead of only verifying the default value.
        let result = path.withPlatformString { pathPointer in
            chflags(pathPointer, UInt32(UF_NODUMP))
        }
        try #require(result == 0)

        let info = try FileInfo(fileAt: path)
        let expected = try Support.ItemMetadata.captureAttributes(at: path)

        #expect(info.attributes == expected.values)
        #expect(info.supportedAttributes == expected.supported)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Directory attrs match BSD stat flags`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        // Explicitly use a nonzero flag instead of only verifying the default value.
        let result = path.withPlatformString { pathPointer in
            chflags(pathPointer, UInt32(UF_NODUMP))
        }
        try #require(result == 0)

        let info = try FileInfo(fileAt: path)
        let expected = try Support.ItemMetadata.captureAttributes(at: path)

        #expect(info.attributes == expected.values)
        #expect(info.supportedAttributes == expected.supported)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Symlink attrs match BSD lstat flags`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let info = try FileInfo(fileAt: link, followSymLink: false)
        let expected = try Support.ItemMetadata.captureAttributes(at: link)

        #expect(info.attributes == expected.values)
        #expect(info.supportedAttributes == expected.supported)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }

    #endif

}

#endif
