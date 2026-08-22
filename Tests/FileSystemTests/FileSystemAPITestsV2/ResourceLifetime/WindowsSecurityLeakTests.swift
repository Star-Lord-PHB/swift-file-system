#if canImport(WinSDK)

import SystemPackage
import Testing
import SwiftFileSystem
import WinSDK



extension ResourceLifetimeTests {

    @Suite("Windows security")
    struct WindowsSecurityLeakTests {

        typealias Support = ResourceLifetimeTests.Support

        typealias LeakChecker = ResourceLifetimeTests.LeakChecker

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension ResourceLifetimeTests.WindowsSecurityLeakTests {

    @Test
    func `Security info query does not leak resources`() throws {

        let path = try workspace.makeFile(at: "file.txt", contents: "contents")

        try LeakChecker.expectNoLeak {
            _ = try fileSystem.getSecurityInfo(forItemAt: path)
            _ = try fileSystem.getSecurityInfo(forItemAt: path, querying: .allExceptSacl)
        }

    }


    @Test
    func `Security info set does not leak resources`() throws {

        let path = try workspace.makeFile(at: "file.txt", contents: "contents")

        try LeakChecker.expectNoLeak {
            let dacl = WindowsRawAcl(
                entries: [
                    .init(permission: .genericAll, inheritance: .noInheritance, trustee: .everyone)
                ]
            )
            try fileSystem.setSecurityInfo(forItemAt: path, dacl: .replace(dacl))
        }

    }

}

#endif
