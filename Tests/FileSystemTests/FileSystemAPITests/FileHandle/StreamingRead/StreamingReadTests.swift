import Testing



extension FileHandleAPITests {

    @Suite("StreamingRead")
    struct StreamingReadTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
