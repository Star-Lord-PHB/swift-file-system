#if canImport(WinSDK)

import Testing



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("Windows security forwarding")
    struct WindowsSecurityTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}

#endif
