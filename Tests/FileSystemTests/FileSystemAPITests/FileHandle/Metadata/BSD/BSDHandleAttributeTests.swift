#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("BSD attributes")
    struct BSDAttributeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.BSDAttributeTests {

    private func setNativeAttributes(
        _ attributes: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let result = path.withPlatformString { pathPointer in
            chflags(pathPointer, attributes.rawValue)
        }
        try #require(result == 0, sourceLocation: sourceLocation)
    }


    @Test
    func `Attribute query matches chflags`() throws {

        let path = try workspace.makeFile(at: "file")
        try setNativeAttributes([.bsd.noDump], at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let actual = try handle.fileAttributes()
        let expected = try Support.ItemMetadata.captureAttributes(at: path).values

        #expect(actual == expected)
        #expect(actual.contains(.bsd.noDump))

        try handle.close()

    }


    @Test
    func `Sets exact attributes`() throws {

        let requestedAttributes: PlatformFileAttributes = [.bsd.noDump]
        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileAttributes(requestedAttributes)

        try handle.close()

        #expect(try Support.ItemMetadata.captureAttributes(at: path).values == requestedAttributes)

    }


    @Test
    func `Empty attributes clear existing flags`() throws {

        let path = try workspace.makeFile(at: "file")
        try setNativeAttributes([.bsd.noDump], at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileAttributes([])

        try handle.close()

        #expect(try Support.ItemMetadata.captureAttributes(at: path).values.isEmpty)

    }

}

#endif
