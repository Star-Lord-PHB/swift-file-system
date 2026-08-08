import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Directory")
    struct DirectoryCopyTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
