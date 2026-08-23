#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Windows attribute setting")
    struct WindowsSetAttributeTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.WindowsSetAttributeTests {

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
    func `Sets file attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        let attributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: attributesBeforeSet
        )

        try fileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        let attributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        #expect(attributesAfterSet == requestedAttributes)

    }


    @Test
    func `Sets dir attributes`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let attributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: attributesBeforeSet
        )

        try fileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        let attributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        #expect(attributesAfterSet == requestedAttributes)

    }


    @Test
    func `Clearing hidden preserves other attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        let preparedAttributes = attributes(
            byAdding: [.windows.isHidden],
            to: try Support.ItemMetadata.captureAttributes(at: path).values
        )
        try setNativeAttributes(preparedAttributes, at: path)

        var requestedAttributes = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        try #require(requestedAttributes.remove(.windows.isHidden) != nil)

        try fileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        let attributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        let expectedAttributes = requestedAttributes.isEmpty
            ? PlatformFileAttributes.windows.isNormal
            : requestedAttributes
        #expect(attributesAfterSet == expectedAttributes)

    }


    @Test
    func `Empty attributes clear file attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        try setNativeAttributes(sampleAttributes, at: path)

        let preparedAttributes = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        try #require(preparedAttributes == sampleAttributes)

        try fileSystem.setAttributes(forItemAt: path, attributes: [])

        let attributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        #expect(attributesAfterSet == .windows.isNormal)

    }


    @Test
    func `Default attribute set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetAttributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: target
        ).values
        let linkAttributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: targetAttributesBeforeSet
        )

        try fileSystem.setAttributes(forItemAt: link, attributes: requestedAttributes)

        let targetAttributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: target
        ).values
        let linkAttributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        #expect(targetAttributesAfterSet == requestedAttributes)
        #expect(linkAttributesAfterSet == linkAttributesBeforeSet)

    }


    @Test
    func `No-follow attribute set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetAttributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: target
        ).values
        let linkAttributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: linkAttributesBeforeSet
        )

        try fileSystem.setAttributes(
            forItemAt: link,
            attributes: requestedAttributes,
            followSymlink: false
        )

        let linkAttributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        let targetAttributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: target
        ).values
        #expect(linkAttributesAfterSet == requestedAttributes)
        #expect(targetAttributesAfterSet == targetAttributesBeforeSet)

    }


    @Test
    func `Empty attributes clear no-follow symlink attributes`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetAttributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: target
        ).values
        try setNativeAttributes(sampleAttributes, at: link)

        let preparedLinkAttributes = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        try #require(preparedLinkAttributes.isSuperset(of: sampleAttributes))
        try fileSystem.setAttributes(forItemAt: link, attributes: [], followSymlink: false)

        let linkAttributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        let targetAttributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: target
        ).values
        #expect(linkAttributesAfterSet == .windows.isReparsePoint)
        #expect(targetAttributesAfterSet == targetAttributesBeforeSet)

    }


    @Test
    func `No-follow attribute set handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkAttributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: linkAttributesBeforeSet
        )

        try fileSystem.setAttributes(
            forItemAt: link,
            attributes: requestedAttributes,
            followSymlink: false
        )

        let linkAttributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        #expect(linkAttributesAfterSet == requestedAttributes)

    }


    @Test
    func `Default attribute set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkAttributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(forItemAt: link, attributes: sampleAttributes)
        }

        let linkAttributesAfterSet = try Support.ItemMetadata.captureAttributes(
            at: link
        ).values
        #expect(error?.kind == .notFound)
        #expect(linkAttributesAfterSet == linkAttributesBeforeSet)

    }


    @Test
    func `Setting attributes for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(forItemAt: path, attributes: sampleAttributes)
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
