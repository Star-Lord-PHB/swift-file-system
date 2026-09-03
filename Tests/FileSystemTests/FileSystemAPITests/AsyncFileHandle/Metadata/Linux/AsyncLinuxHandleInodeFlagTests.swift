#if canImport(Glibc) || canImport(Musl)

import Testing



extension AsyncFileHandleAPITests.MetadataTests {

    @Suite("Linux inode flags")
    struct LinuxInodeFlagTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}

#endif
