import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Directory merge")
    struct DirectoryMergeTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
