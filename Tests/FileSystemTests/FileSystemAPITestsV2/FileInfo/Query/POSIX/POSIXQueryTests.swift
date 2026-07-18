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

    private func nativeStat(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> stat {
        var metadata = stat()
        let result = path.withPlatformString { pathPointer in
            if followSymlink {
                stat(pathPointer, &metadata)
            } else {
                lstat(pathPointer, &metadata)
            }
        }
        try #require(result == 0, sourceLocation: sourceLocation)
        return metadata
    }


    private func identifier(from metadata: stat) -> FileIdentifier {
        .init(
            fileId: UInt64(metadata.st_ino),
            deviceId: UInt32(truncatingIfNeeded: metadata.st_dev)
        )
    }


    @Test
    func `Regular file identifier matches stat`() throws {

        let path = try workspace.makeFile(at: "file")

        let info = try FileInfo(fileAt: path)
        let expected = try nativeStat(at: path, followSymlink: true)

        #expect(info.fileIdentifier == identifier(from: expected))

    }


    @Test
    func `Directory identifier matches stat`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let info = try FileInfo(fileAt: path)
        let expected = try nativeStat(at: path, followSymlink: true)

        #expect(info.fileIdentifier == identifier(from: expected))

    }


    @Test
    func `Symlink identifiers match stat and lstat`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let followedInfo = try FileInfo(fileAt: link, followSymLink: true)
        let directInfo = try FileInfo(fileAt: link, followSymLink: false)
        let followedExpected = try nativeStat(at: link, followSymlink: true)
        let directExpected = try nativeStat(at: link, followSymlink: false)

        #expect(followedInfo.fileIdentifier == identifier(from: followedExpected))
        #expect(directInfo.fileIdentifier == identifier(from: directExpected))

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
        let expected = try nativeStat(at: path, followSymlink: true)

        #expect(info.attributes.rawValue == expected.st_flags)
        #expect(info.supportedAttributes == .all)
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
        let expected = try nativeStat(at: path, followSymlink: true)

        #expect(info.attributes.rawValue == expected.st_flags)
        #expect(info.supportedAttributes == .all)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Symlink attrs match BSD lstat flags`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let info = try FileInfo(fileAt: link, followSymLink: false)
        let expected = try nativeStat(at: link, followSymlink: false)

        #expect(info.attributes.rawValue == expected.st_flags)
        #expect(info.supportedAttributes == .all)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }

    #endif

}

#endif
