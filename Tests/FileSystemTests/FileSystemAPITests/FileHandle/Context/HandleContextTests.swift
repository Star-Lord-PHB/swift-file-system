import Testing
import SwiftFileSystem
#if canImport(WinSDK)
import WinSDK
#else
import PlatformCLib
#endif



extension FileHandleAPITests {

    /// `UnsafeHandleContextView`, the borrowed view every handle lends through
    /// `unsafeHandleContext`: the system handle it exposes and, on Windows, the per-call reopen
    /// behind the metadata setters.
    @Suite("Handle context")
    struct HandleContextTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.HandleContextTests {

    private func isOpen(_ rawHandle: UnsafeSystemHandle.SystemHandleType) -> Bool {
        #if canImport(WinSDK)
        var flags = 0 as DWORD
        return GetHandleInformation(rawHandle, &flags)
        #else
        return fcntl(rawHandle, F_GETFD) != -1
        #endif
    }


    // `systemHandle` is a `_read` accessor over a temporary owning handle. A caller that throws
    // inside the access aborts the coroutine, and the temporary must still not close the handle
    // it never owned.
    @Test
    func `Throwing inside a borrowed system handle access keeps the handle open`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        let context = handle.unsafeHandleContext
        let rawHandle = context.systemHandle.unsafeRawHandle

        #expect(try context.systemHandle.fileInfo().size == 8)

        let error = #expect(throws: LowLevelError.self) {
            _ = try context.systemHandle.seek(to: -1)
        }
        #expect(error?.kind == .invalidInput)

        #expect(isOpen(rawHandle))
        #expect(try handle.fileInfo().size == 8)

    }

}
