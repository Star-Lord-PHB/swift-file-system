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

    private var sampleAttributes: PlatformFileAttributes {
        [.windows.isHidden, .windows.isNotContentIndexed]
    }


    private func attributes(
        byAdding additions: PlatformFileAttributes,
        to rawAttributes: PlatformInteropTypes.FileAttribute
    ) -> PlatformFileAttributes {
        return PlatformFileAttributes(rawValue: rawAttributes)
            .subtracting(.windows.isNormal).union(additions)
    }


    @Test
    func `Sets file attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        let infoBeforeSet = try Support.captureWindowsBasicInfo(at: path, followSymlink: true)
        let requestedAttributes = attributes(byAdding: sampleAttributes, to: infoBeforeSet.attributes)

        try fileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        let infoAfterSet = try Support.captureWindowsBasicInfo(at: path, followSymlink: true)
        #expect(infoAfterSet.attributes == requestedAttributes.rawValue)

    }


    @Test
    func `Sets dir attributes`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let infoBeforeSet = try Support.captureWindowsBasicInfo(at: path, followSymlink: true)
        let requestedAttributes = attributes(byAdding: sampleAttributes, to: infoBeforeSet.attributes)

        try fileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        let infoAfterSet = try Support.captureWindowsBasicInfo(at: path, followSymlink: true)
        #expect(infoAfterSet.attributes == requestedAttributes.rawValue)

    }


    @Test
    func `Clearing hidden preserves other attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        let preparedAttributes = attributes(
            byAdding: [.windows.isHidden],
            to: try Support.captureWindowsBasicInfo(at: path, followSymlink: true).attributes
        )
        try Support.setNativeWindowsAttributes(preparedAttributes, at: path)

        let infoBeforeSet = try Support.captureWindowsBasicInfo(at: path, followSymlink: true)
        var requestedAttributes = PlatformFileAttributes(rawValue: infoBeforeSet.attributes)
        try #require(requestedAttributes.remove(.windows.isHidden) != nil)

        try fileSystem.setAttributes(forItemAt: path, attributes: requestedAttributes)

        let infoAfterSet = try Support.captureWindowsBasicInfo(at: path, followSymlink: true)
        let expectedAttributes = requestedAttributes.isEmpty
            ? PlatformFileAttributes.windows.isNormal
            : requestedAttributes
        #expect(infoAfterSet.attributes == expectedAttributes.rawValue)

    }


    @Test
    func `Empty attributes clear file attributes`() throws {

        let path = try workspace.makeFile(at: "file")
        try Support.setNativeWindowsAttributes(sampleAttributes, at: path)

        let preparedInfo = try Support.captureWindowsBasicInfo(at: path, followSymlink: true)
        try #require(preparedInfo.attributes == sampleAttributes.rawValue)

        try fileSystem.setAttributes(forItemAt: path, attributes: [])

        let infoAfterSet = try Support.captureWindowsBasicInfo(at: path, followSymlink: true)
        #expect(infoAfterSet.attributes == PlatformFileAttributes.windows.isNormal.rawValue)

    }


    @Test
    func `Default attribute set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetInfoBeforeSet = try Support.captureWindowsBasicInfo(at: target, followSymlink: true)
        let linkInfoBeforeSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: targetInfoBeforeSet.attributes
        )

        try fileSystem.setAttributes(forItemAt: link, attributes: requestedAttributes)

        let targetInfoAfterSet = try Support.captureWindowsBasicInfo(at: target, followSymlink: true)
        let linkInfoAfterSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        #expect(targetInfoAfterSet.attributes == requestedAttributes.rawValue)
        #expect(linkInfoAfterSet.attributes == linkInfoBeforeSet.attributes)

    }


    @Test
    func `No-follow attribute set changes symlink only`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetInfoBeforeSet = try Support.captureWindowsBasicInfo(at: target, followSymlink: true)
        let linkInfoBeforeSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: linkInfoBeforeSet.attributes
        )

        try fileSystem.setAttributes(
            forItemAt: link,
            attributes: requestedAttributes,
            followSymlink: false
        )

        let linkInfoAfterSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        let targetInfoAfterSet = try Support.captureWindowsBasicInfo(at: target, followSymlink: true)
        #expect(linkInfoAfterSet.attributes == requestedAttributes.rawValue)
        #expect(targetInfoAfterSet.attributes == targetInfoBeforeSet.attributes)

    }


    @Test
    func `Empty attributes clear no-follow symlink attributes`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetInfoBeforeSet = try Support.captureWindowsBasicInfo(at: target, followSymlink: true)
        try Support.setNativeWindowsAttributes(sampleAttributes, at: link)

        let preparedLinkInfo = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        try #require(
            PlatformFileAttributes(rawValue: preparedLinkInfo.attributes)
                .isSuperset(of: sampleAttributes)
        )
        try fileSystem.setAttributes(forItemAt: link, attributes: [], followSymlink: false)

        let linkInfoAfterSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        let targetInfoAfterSet = try Support.captureWindowsBasicInfo(at: target, followSymlink: true)
        #expect(linkInfoAfterSet.attributes == PlatformFileAttributes.windows.isReparsePoint.rawValue)
        #expect(targetInfoAfterSet.attributes == targetInfoBeforeSet.attributes)

    }


    @Test
    func `No-follow attribute set handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkInfoBeforeSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        let requestedAttributes = attributes(
            byAdding: sampleAttributes,
            to: linkInfoBeforeSet.attributes
        )

        try fileSystem.setAttributes(
            forItemAt: link,
            attributes: requestedAttributes,
            followSymlink: false
        )

        let linkInfoAfterSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        #expect(linkInfoAfterSet.attributes == requestedAttributes.rawValue)

    }


    @Test
    func `Default attribute set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")
        let linkInfoBeforeSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setAttributes(forItemAt: link, attributes: sampleAttributes)
        }

        let linkInfoAfterSet = try Support.captureWindowsBasicInfo(at: link, followSymlink: false)
        #expect(error?.kind == .notFound)
        #expect(linkInfoAfterSet.attributes == linkInfoBeforeSet.attributes)

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
