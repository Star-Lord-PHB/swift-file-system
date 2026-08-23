#if canImport(WinSDK)

import SystemPackage
import Testing
import SwiftFileSystem



extension FileInfoAPITests.QueryTests {

    @Suite("Windows fields")
    struct WindowsQueryTests {

        typealias Support = FileInfoAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileInfoAPITests.QueryTests.WindowsQueryTests {


    @Test
    func `Regular file fields match Win32`() throws {

        let path = try workspace.makeFile(at: "file")

        let info = try FileInfo(fileAt: path)
        let expectedIdentifier = try Support.ItemMetadata.captureIdentifier(at: path)
        let expectedAttributes = try Support.ItemMetadata.captureAttributes(at: path)

        #expect(info.fileIdentifier == expectedIdentifier)
        #expect(info.attributes == expectedAttributes.values)
        #expect(info.supportedAttributes == expectedAttributes.supported)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Directory fields match Win32`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let info = try FileInfo(fileAt: path)
        let expectedIdentifier = try Support.ItemMetadata.captureIdentifier(at: path)
        let expectedAttributes = try Support.ItemMetadata.captureAttributes(at: path)

        #expect(info.fileIdentifier == expectedIdentifier)
        #expect(info.attributes == expectedAttributes.values)
        #expect(info.supportedAttributes == expectedAttributes.supported)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Symlink fields respect follow option`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let followedInfo = try FileInfo(fileAt: link, followSymLink: true)
        let directInfo = try FileInfo(fileAt: link, followSymLink: false)
        let followedExpectedIdentifier = try Support.ItemMetadata.captureIdentifier(at: target)
        let directExpectedIdentifier = try Support.ItemMetadata.captureIdentifier(at: link)
        let followedExpectedAttributes = try Support.ItemMetadata.captureAttributes(at: target)
        let directExpectedAttributes = try Support.ItemMetadata.captureAttributes(at: link)

        #expect(followedInfo.fileIdentifier == followedExpectedIdentifier)
        #expect(followedInfo.attributes == followedExpectedAttributes.values)
        #expect(followedInfo.supportedAttributes == followedExpectedAttributes.supported)
        #expect(followedInfo.attributes.isSubset(of: followedInfo.supportedAttributes))

        #expect(directInfo.fileIdentifier == directExpectedIdentifier)
        #expect(directInfo.attributes == directExpectedAttributes.values)
        #expect(directInfo.supportedAttributes == directExpectedAttributes.supported)
        #expect(directInfo.attributes.isSubset(of: directInfo.supportedAttributes))

    }


    @Test
    func `Junction is unknown without follow and its target kind with follow`() throws {

        let target = try workspace.makeDirectory(at: "target")
        let junction = workspace.path("junction")
        try Support.makeWindowsJunction(at: junction, pointingTo: target)

        // A name-surrogate reparse point that is not a symlink is deliberately not modeled.
        let directInfo = try FileInfo(fileAt: junction, followSymLink: false)
        #expect(directInfo.type == .unknown)

        // Following resolves the junction like a symlink and reports the target.
        let followedInfo = try FileInfo(fileAt: junction, followSymLink: true)
        #expect(followedInfo.type == .directory)
        let targetIdentifier = try Support.ItemMetadata.captureIdentifier(at: target)
        #expect(followedInfo.fileIdentifier == targetIdentifier)

    }

}

#endif
