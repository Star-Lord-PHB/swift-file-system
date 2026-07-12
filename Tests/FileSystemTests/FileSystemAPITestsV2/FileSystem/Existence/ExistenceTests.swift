import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Existence")
    struct ExistenceTests {

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.ExistenceTests {

    @Test
    func `Regular file exists`() throws {

        let path = try workspace.makeFile(at: "file.txt")

        #expect(fileSystem.itemExists(at: path))

    }


    @Test
    func `Directory exists`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        #expect(fileSystem.itemExists(at: path))

    }


    @Test
    func `Symbolic link exists without following its target`() throws {

        let target = try workspace.makeFile(at: "target.txt")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        #expect(fileSystem.itemExists(at: link, followSymlinks: false))

    }


    @Test
    func `Dangling symbolic link exists without following its target`() throws {

        let missingTarget = workspace.path("missing-target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: missingTarget)

        #expect(fileSystem.itemExists(at: link, followSymlinks: false))

    }


    @Test
    func `Symbolic-link target exists by default`() throws {

        let target = try workspace.makeFile(at: "target.txt")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        #expect(fileSystem.itemExists(at: link))

    }


    @Test
    func `Missing item does not exist`() throws {

        let path = workspace.path("missing")

        #expect(!fileSystem.itemExists(at: path))

    }


    @Test
    func `Dangling symbolic-link target does not exist by default`() throws {

        let missingTarget = workspace.path("missing-target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: missingTarget)

        #expect(!fileSystem.itemExists(at: link))

    }

}
