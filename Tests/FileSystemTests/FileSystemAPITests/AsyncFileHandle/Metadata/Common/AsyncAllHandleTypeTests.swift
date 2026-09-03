import Testing



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("All handle types")
    struct AllHandleTypeTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
