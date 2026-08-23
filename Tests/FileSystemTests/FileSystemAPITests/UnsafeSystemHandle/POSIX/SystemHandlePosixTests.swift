#if !canImport(WinSDK)

import Testing



extension UnsafeSystemHandleAPITests {

    /// POSIX-only behavior of `UnsafeSystemHandle`: creation permissions and their umask
    /// interaction, native open-flag observation (FD_CLOEXEC, no-follow, O_DIRECTORY, O_PATH),
    /// and the pipe readiness facilities (poll, setNonBlocking).
    @Suite("POSIX")
    struct PosixTests {

        typealias Support = UnsafeSystemHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}

#endif
