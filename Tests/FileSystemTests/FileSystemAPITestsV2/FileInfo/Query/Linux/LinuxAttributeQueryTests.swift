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

    private struct NativeAttributes {
        let attributes: UInt64
        let supportedAttributes: UInt64
    }


    private func nativeAttributes(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> NativeAttributes {
        var metadata = StatCompat()
        let flags = followSymlink ? CInt(0) : CInt(AT_SYMLINK_NOFOLLOW)
        let result = path.withPlatformString { pathPointer in
            systemStatCompat(pathPointer, flags, &metadata)
        }
        try #require(result == 0, sourceLocation: sourceLocation)
        return .init(
            attributes: metadata.st_attributes,
            supportedAttributes: metadata.st_attributes_mask
        )
    }


    @Test
    func `Regular file attrs match statx`() throws {

        let path = try workspace.makeFile(at: "file")

        let info = try FileInfo(fileAt: path)
        let expected = try nativeAttributes(at: path, followSymlink: true)

        #expect(info.attributes.rawValue == expected.attributes)
        #expect(info.supportedAttributes.rawValue == expected.supportedAttributes)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Directory attrs match statx`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let info = try FileInfo(fileAt: path)
        let expected = try nativeAttributes(at: path, followSymlink: true)

        #expect(info.attributes.rawValue == expected.attributes)
        #expect(info.supportedAttributes.rawValue == expected.supportedAttributes)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Symlink attrs match no-follow statx`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let info = try FileInfo(fileAt: link, followSymLink: false)
        let expected = try nativeAttributes(at: link, followSymlink: false)

        #expect(info.attributes.rawValue == expected.attributes)
        #expect(info.supportedAttributes.rawValue == expected.supportedAttributes)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }

}

#endif
