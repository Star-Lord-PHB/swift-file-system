#if canImport(Glibc) || canImport(Musl)

import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Linux inode flags")
    struct LinuxInodeFlagTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.LinuxInodeFlagTests {


    @Test
    func `File flag query matches ioctl`() throws {

        let path = try workspace.makeFile(at: "file")
        var preparedFlags = try Support.captureNativeInodeFlags(at: path)
        preparedFlags.insert(.noDump)
        try Support.setNativeInodeFlags(preparedFlags, at: path)

        let actual = try fileSystem.getInodeFlags(forItemAt: path)
        let expected = try Support.captureNativeInodeFlags(at: path)

        #expect(actual == expected)
        #expect(actual.contains(.noDump))

    }


    @Test
    func `Dir flag query matches ioctl`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        var preparedFlags = try Support.captureNativeInodeFlags(at: path)
        preparedFlags.insert(.noDump)
        try Support.setNativeInodeFlags(preparedFlags, at: path)

        let actual = try fileSystem.getInodeFlags(forItemAt: path)
        let expected = try Support.captureNativeInodeFlags(at: path)

        #expect(actual == expected)
        #expect(actual.contains(.noDump))

    }


    @Test
    func `Flag query follows symlink by default`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        var preparedFlags = try Support.captureNativeInodeFlags(at: target)
        preparedFlags.insert(.noDump)
        try Support.setNativeInodeFlags(preparedFlags, at: target)

        let actual = try fileSystem.getInodeFlags(forItemAt: link)
        let expected = try Support.captureNativeInodeFlags(at: target)

        #expect(actual == expected)

    }


    @Test
    func `No-follow flag query rejects symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getInodeFlags(
                forItemAt: link,
                followSymlink: false
            )
        }

        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)

    }


    @Test
    func `Default flag query fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getInodeFlags(forItemAt: link)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `No-follow flag query rejects dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getInodeFlags(
                forItemAt: link,
                followSymlink: false
            )
        }

        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)

    }


    @Test
    func `Missing flag query fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.getInodeFlags(forItemAt: path)
        }

        #expect(error?.kind == .notFound)

    }

}



extension FileSystemAPITests.MetadataTests.LinuxInodeFlagTests {

    @Test
    func `Sets file inode flags`() throws {

        let path = try workspace.makeFile(at: "file")
        var requestedFlags = try Support.captureNativeInodeFlags(at: path)
        requestedFlags.insert(.noDump)

        try fileSystem.setInodeFlags(
            forItemAt: path,
            flags: requestedFlags
        )

        #expect(try Support.captureNativeInodeFlags(at: path) == requestedFlags)

    }


    @Test
    func `Sets dir inode flags`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        var requestedFlags = try Support.captureNativeInodeFlags(at: path)
        requestedFlags.insert(.noDump)

        try fileSystem.setInodeFlags(
            forItemAt: path,
            flags: requestedFlags
        )

        #expect(try Support.captureNativeInodeFlags(at: path) == requestedFlags)

    }


    @Test
    func `Clearing noDump preserves existing flags`() throws {

        let path = try workspace.makeFile(at: "file")
        let flagsBeforeSet = try Support.captureNativeInodeFlags(at: path)
        try Support.setNativeInodeFlags(flagsBeforeSet.union(.noDump), at: path)

        try fileSystem.setInodeFlags(
            forItemAt: path,
            flags: flagsBeforeSet
        )

        #expect(try Support.captureNativeInodeFlags(at: path) == flagsBeforeSet)

    }


    @Test
    func `Default flag set follows symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        var requestedFlags = try Support.captureNativeInodeFlags(at: target)
        requestedFlags.insert(.noDump)

        try fileSystem.setInodeFlags(
            forItemAt: link,
            flags: requestedFlags
        )

        #expect(try Support.captureNativeInodeFlags(at: target) == requestedFlags)

    }


    @Test
    func `No-follow flag set rejects symlink`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)
        let targetFlagsBeforeSet = try Support.captureNativeInodeFlags(at: target)
        var requestedFlags = targetFlagsBeforeSet
        requestedFlags.insert(.noDump)

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setInodeFlags(
                forItemAt: link,
                flags: requestedFlags,
                followSymlink: false
            )
        }

        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)
        #expect(try Support.captureNativeInodeFlags(at: target) == targetFlagsBeforeSet)

    }


    @Test
    func `Default flag set fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setInodeFlags(
                forItemAt: link,
                flags: [.noDump]
            )
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `No-follow flag set rejects dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setInodeFlags(
                forItemAt: link,
                flags: [.noDump],
                followSymlink: false
            )
        }

        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)

    }


    @Test
    func `Setting flags for missing item fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.setInodeFlags(
                forItemAt: path,
                flags: [.noDump]
            )
        }

        #expect(error?.kind == .notFound)

    }

}

#endif
