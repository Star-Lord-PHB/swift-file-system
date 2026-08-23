import Testing
import Foundation
import SwiftFileSystem

#if canImport(WinSDK)
import WinSDK
#else
import PlatformCLib
#endif



extension UnsafeSystemHandleAPITests {

    /// Ownership and lifetime of `UnsafeSystemHandle`: close, implicit deinit, take and
    /// duplicate. Release is verified with `SystemHandleProbe`, whose re-query plus file-identity
    /// check stays race-free under parallel test execution.
    @Suite("Lifecycle")
    struct LifecycleTests {

        typealias Support = UnsafeSystemHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension UnsafeSystemHandleAPITests.LifecycleTests {

    @Test
    func `close releases the underlying handle`() throws {

        let path = try workspace.makeFile(at: "file")

        let handle = try UnsafeSystemHandle.open(at: path)
        let probe = try Support.SystemHandleProbe(capturing: handle)

        try #require(!probe.isReleased)

        try handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `Dropping a handle without close releases the underlying handle`() throws {

        let path = try workspace.makeFile(at: "file")

        let probe: Support.SystemHandleProbe

        do {
            let handle = try UnsafeSystemHandle.open(at: path)
            probe = try Support.SystemHandleProbe(capturing: handle)
        }

        #expect(probe.isReleased)

    }


    @Test
    func `take detaches ownership without closing`() throws {

        let path = try workspace.makeFile(at: "file")

        let handle = try UnsafeSystemHandle.open(at: path)
        let probe = try Support.SystemHandleProbe(capturing: handle)

        let rawHandle = handle.take()

        #expect(!probe.isReleased)

        #if canImport(WinSDK)
        CloseHandle(rawHandle)
        #else
        PlatformCLib.close(rawHandle)
        #endif

        #expect(probe.isReleased)

    }


    @Test
    func `Duplicate shares the file offset with the original`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path)
        let duplicate = try handle.duplicate()

        try handle.seek(to: 6)

        #expect(try duplicate.tell() == 6)

        var buffer = Data(count: 6)

        try #expect(duplicate.read(into: buffer.mutableBytes) == 6)

        #expect(buffer == Data("Swift!".utf8))
        #expect(try handle.tell() == 12)

        try duplicate.close()
        try handle.close()

    }


    @Test
    func `Duplicate stays usable after the original closes`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello")

        let handle = try UnsafeSystemHandle.open(at: path)
        let duplicate = try handle.duplicate()

        try handle.close()

        var buffer = Data(count: 5)

        try #expect(duplicate.read(into: buffer.mutableBytes) == 5)

        #expect(buffer == Data("Hello".utf8))

        try duplicate.close()

    }

}
