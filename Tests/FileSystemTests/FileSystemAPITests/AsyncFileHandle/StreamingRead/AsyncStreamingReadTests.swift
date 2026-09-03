import Testing



extension AsyncFileHandleAPITests {

    @Suite("StreamingRead")
    struct StreamingReadTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
