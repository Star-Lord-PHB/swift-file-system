#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileHandleAPITests.MetadataTests {

    @Suite("Windows attributes")
    struct WindowsAttributeTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.MetadataTests.WindowsAttributeTests {

    private func setNativeAttributes(
        _ attributes: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let success = path.withPlatformString { pathPointer in
            SetFileAttributesW(pathPointer, attributes.rawValue)
        }
        try #require(success, sourceLocation: sourceLocation)
    }


    private var sampleAttributes: PlatformFileAttributes {
        [.windows.isHidden, .windows.isNotContentIndexed]
    }


    private func attributes(
        byAdding additions: PlatformFileAttributes,
        to attributes: PlatformFileAttributes
    ) -> PlatformFileAttributes {
        attributes.subtracting(.windows.isNormal).union(additions)
    }


    @Test
    func `Attribute query matches Win32`() throws {

        let path = try workspace.makeFile(at: "file")
        try setNativeAttributes(sampleAttributes, at: path)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        let actual = try handle.fileAttributes()
        let expected = try Support.ItemMetadata.captureAttributes(at: path).values

        #expect(actual == expected)
        #expect(actual.isSuperset(of: sampleAttributes))

        try handle.close()

    }


    @Test
    func `Sets file attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        let attributesBeforeSet = try Support.ItemMetadata.captureAttributes(at: path).values
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: attributesBeforeSet
        )
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileAttributes(requestedAttributes)

        try handle.close()

        let attributesAfterSet = try Support.ItemMetadata.captureAttributes(at: path).values
        #expect(attributesAfterSet == requestedAttributes)

    }


    @Test
    func `Clearing hidden preserves other attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        let preparedAttributes = attributes(
            byAdding: [.windows.isHidden, .windows.isNotContentIndexed],
            to: try Support.ItemMetadata.captureAttributes(at: path).values
        )
        try setNativeAttributes(preparedAttributes, at: path)

        var requestedAttributes = try Support.ItemMetadata.captureAttributes(at: path).values
        try #require(requestedAttributes.remove(.windows.isHidden) != nil)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileAttributes(requestedAttributes)

        try handle.close()

        let attributesAfterSet = try Support.ItemMetadata.captureAttributes(at: path).values
        #expect(attributesAfterSet == requestedAttributes)

    }


    @Test
    func `Empty attributes clear file attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        try setNativeAttributes(sampleAttributes, at: path)
        let preparedAttributes = try Support.ItemMetadata.captureAttributes(at: path).values
        try #require(preparedAttributes == sampleAttributes)
        let handle = try ReadWriteFileHandle(forFileAt: path)

        try handle.setFileAttributes([])

        try handle.close()

        let attributesAfterSet = try Support.ItemMetadata.captureAttributes(at: path).values
        #expect(attributesAfterSet == .windows.isNormal)

    }

}

#endif
