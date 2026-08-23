#if canImport(Glibc) || canImport(Musl)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Linux attribute setting")
    struct LinuxSetAttributeTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.LinuxSetAttributeTests {

    @Test
    func `Sets file noDump attribute`() throws {

        let path = try workspace.makeFile(at: "file")

        try fileSystem.setAttributes(
            forItemAt: path,
            attributes: [.linux.noDump]
        )

        #expect(
            try Support.ItemMetadata.captureAttributes(at: path).values
                .contains(.linux.noDump)
        )

    }


    @Test
    func `Sets dir noDump attribute`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        try fileSystem.setAttributes(
            forItemAt: path,
            attributes: [.linux.noDump]
        )

        #expect(
            try Support.ItemMetadata.captureAttributes(at: path).values
                .contains(.linux.noDump)
        )

    }


    @Test
    func `Clearing noDump preserves other attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        let flagsBeforeSet = try Support.captureNativeInodeFlags(at: path)
        try Support.setNativeInodeFlags(flagsBeforeSet.union(.noDump), at: path)
        var requestedAttributes = try Support.ItemMetadata.captureAttributes(
            at: path
        ).values
        try #require(requestedAttributes.remove(.linux.noDump) != nil)

        try fileSystem.setAttributes(
            forItemAt: path,
            attributes: requestedAttributes
        )

        #expect(
            try Support.ItemMetadata.captureAttributes(at: path).values
                == requestedAttributes
        )

    }


    @Test
    func `Default attribute set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        try fileSystem.setAttributes(
            forItemAt: link,
            attributes: [.linux.noDump]
        )

        #expect(
            try Support.ItemMetadata.captureAttributes(at: target).values
                .contains(.linux.noDump)
        )

    }


    @Test
    func `No-follow attribute set rejects symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetAttributesBeforeSet = try Support.ItemMetadata.captureAttributes(
            at: target
        ).values

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(
                forItemAt: link,
                attributes: [.linux.noDump],
                followSymlink: false
            )
        }

        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)
        #expect(
            try Support.ItemMetadata.captureAttributes(at: target).values
                == targetAttributesBeforeSet
        )

    }


    @Test
    func `Default attribute set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(
                forItemAt: link,
                attributes: [.linux.noDump]
            )
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `No-follow attribute set rejects dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(
                forItemAt: link,
                attributes: [.linux.noDump],
                followSymlink: false
            )
        }

        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)

    }


    @Test
    func `Setting attributes for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(
                forItemAt: path,
                attributes: [.linux.noDump]
            )
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
