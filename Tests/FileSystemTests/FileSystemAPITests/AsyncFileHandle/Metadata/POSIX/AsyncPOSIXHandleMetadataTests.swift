#if !canImport(WinSDK)

import Testing



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("POSIX forwarding")
    struct POSIXForwardingTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}

#endif
