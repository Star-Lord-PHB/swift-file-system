#if canImport(WinSDK)

import Testing



extension UnsafeSystemHandleAPITests {

    /// Windows-only behavior of `UnsafeSystemHandle`: share modes, handle inheritance, backup
    /// semantics, creation security descriptors, the no-follow truncate guard, and overlapped
    /// I/O.
    @Suite("Windows")
    struct WindowsTests {

        typealias Support = UnsafeSystemHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}

#endif
