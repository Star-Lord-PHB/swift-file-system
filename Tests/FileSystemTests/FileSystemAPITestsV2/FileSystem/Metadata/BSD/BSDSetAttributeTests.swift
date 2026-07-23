#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("BSD attribute setting")
    struct BSDSetAttributeTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.BSDSetAttributeTests {

    private func nativeAttributes(
        at path: FilePath,
        followSymlink: Bool = true
    ) throws -> PlatformFileAttributes {
        let metadata = try Stat(path, followTargetSymlink: followSymlink)
        return .init(rawValue: metadata.flags.rawValue)
    }


    private func setNativeAttributes(
        _ attributes: PlatformFileAttributes,
        at path: FilePath,
        followSymlink: Bool = true,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let result = path.withPlatformString { pathPointer in
            followSymlink
                ? chflags(pathPointer, attributes.rawValue)
                : lchflags(pathPointer, attributes.rawValue)
        }
        try #require(result == 0, sourceLocation: sourceLocation)
        try #require(
            nativeAttributes(at: path, followSymlink: followSymlink) == attributes,
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `Sets exact file attributes`() throws {

        let requestedAttributes: PlatformFileAttributes = [.bsd.noDump]
        let path = try workspace.makeFile(at: "file")

        try fileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        #expect(try nativeAttributes(at: path) == requestedAttributes)

    }


    @Test
    func `Sets exact dir attributes`() throws {

        let requestedAttributes: PlatformFileAttributes = [.bsd.noDump]
        let path = try workspace.makeDirectory(at: "directory")

        try fileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        #expect(try nativeAttributes(at: path) == requestedAttributes)

    }


    @Test
    func `Empty attributes clear existing flags`() throws {

        let path = try workspace.makeFile(at: "file")
        try setNativeAttributes([.bsd.noDump], at: path)

        try fileSystem.setAttributes(forItemAt: path, attributes: [])

        #expect(try nativeAttributes(at: path).isEmpty)

    }


    @Test
    func `Default attribute set follows symlink`() throws {

        let requestedAttributes: PlatformFileAttributes = [.bsd.noDump]
        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let linkAttributesBeforeSet = try nativeAttributes(
            at: link,
            followSymlink: false
        )

        try fileSystem.setAttributes(forItemAt: link, attributes: requestedAttributes)

        let linkAttributesAfterSet = try nativeAttributes(
            at: link,
            followSymlink: false
        )
        #expect(try nativeAttributes(at: target) == requestedAttributes)
        #expect(linkAttributesAfterSet == linkAttributesBeforeSet)

    }


    @Test
    func `No-follow attribute set changes symlink only`() throws {

        let requestedAttributes: PlatformFileAttributes = [.bsd.noDump]
        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetAttributesBeforeSet = try nativeAttributes(at: target)

        try fileSystem.setAttributes(
            forItemAt: link,
            attributes: requestedAttributes,
            followSymlink: false
        )

        let targetAttributesAfterSet = try nativeAttributes(at: target)
        #expect(try nativeAttributes(at: link, followSymlink: false) == requestedAttributes)
        #expect(targetAttributesAfterSet == targetAttributesBeforeSet)

    }


    @Test
    func `No-follow attribute set handles dangling symlink`() throws {

        let requestedAttributes: PlatformFileAttributes = [.bsd.noDump]
        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        try fileSystem.setAttributes(
            forItemAt: link,
            attributes: requestedAttributes,
            followSymlink: false
        )

        #expect(try nativeAttributes(at: link, followSymlink: false) == requestedAttributes)

    }


    @Test
    func `Default attribute set fails for dangling symlink`() throws {

        let requestedAttributes: PlatformFileAttributes = [.bsd.noDump]
        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkAttributesBeforeSet = try nativeAttributes(
            at: link,
            followSymlink: false
        )

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(forItemAt: link, attributes: requestedAttributes)
        }

        let linkAttributesAfterSet = try nativeAttributes(
            at: link,
            followSymlink: false
        )
        #expect(error?.kind == .notFound)
        #expect(linkAttributesAfterSet == linkAttributesBeforeSet)

    }


    @Test
    func `Setting attributes for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(forItemAt: path, attributes: [.bsd.noDump])
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
