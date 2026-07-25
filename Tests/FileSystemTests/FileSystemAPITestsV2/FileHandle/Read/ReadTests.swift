import Testing



extension FileHandleAPITests {

    @Suite("Read")
    struct ReadTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
