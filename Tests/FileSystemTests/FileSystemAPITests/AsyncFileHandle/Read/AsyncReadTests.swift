import Testing



extension AsyncFileHandleAPITests {

    @Suite("Read")
    struct ReadTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
