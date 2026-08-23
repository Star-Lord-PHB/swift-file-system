import Testing
import SwiftFileSystem



extension FileSystemAPITests.MetadataTests {

    @Suite("Info")
    struct InfoTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.MetadataTests.InfoTests {

    @Test
    func `Regular file query matches FileInfo`() throws {

        let path = try workspace.makeFile(at: "file", contents: "file contents")

        let actual = try fileSystem.info(ofItemAt: path)
        let expected = try FileInfo(fileAt: path)

        #expect(actual == expected)

    }


    @Test
    func `Directory query matches FileInfo`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let actual = try fileSystem.info(ofItemAt: path)
        let expected = try FileInfo(fileAt: path)

        #expect(actual == expected)

    }


    @Test
    func `Default query follows symlinks`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let actual = try fileSystem.info(ofItemAt: link)
        let expected = try FileInfo(fileAt: link, followSymLink: true)

        #expect(actual == expected)

    }


    @Test
    func `No-follow query returns symlink info`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let actual = try fileSystem.info(ofItemAt: link, followSymlinks: false)
        let expected = try FileInfo(fileAt: link, followSymLink: false)

        #expect(actual == expected)

    }


    @Test
    func `No-follow query handles dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let actual = try fileSystem.info(ofItemAt: link, followSymlinks: false)
        let expected = try FileInfo(fileAt: link, followSymLink: false)

        #expect(actual == expected)

    }


    @Test
    func `Default query fails for dangling symlink`() throws {

        let link = try workspace.makeSymlink(at: "link", pointingTo: "missing-target")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.info(ofItemAt: link)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Missing item query fails`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.info(ofItemAt: path)
        }

        #expect(error?.kind == .notFound)

    }

}
