import Testing



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("Forwarding")
    struct ForwardingTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
