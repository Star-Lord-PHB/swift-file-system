import Testing
import SwiftFileSystem



extension FileHandleAPITests.LifecycleTests {

    @Test
    func `ReadFileHandle close releases the system handle`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadFileHandle(forFileAt: path)
        let probe = try handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `WriteFileHandle close releases the system handle`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try WriteFileHandle(forFileAt: path)
        let probe = try handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `ReadWriteFileHandle close releases the system handle`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try ReadWriteFileHandle(forFileAt: path)
        let probe = try handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `AppendHandle close releases the system handle`() throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try AppendHandle(forFileAt: path)
        let probe = try handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `DirectoryHandle close releases the system handle`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let handle = try DirectoryHandle(forDirAt: path)
        let probe = try handle.withUnsafeSystemHandle {
            try Support.SystemHandleProbe(capturing: $0)
        }

        try handle.close()

        #expect(probe.isReleased)

    }


    @Test
    func `Dropping a handle without close releases the system handle`() throws {

        let path = try workspace.makeFile(at: "file")
        let probe: Support.SystemHandleProbe

        do {
            let handle = try ReadWriteFileHandle(forFileAt: path)
            probe = try handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
        }

        #expect(probe.isReleased)

    }


    @Test
    func `Dropping a write handle without close preserves written data`() throws {

        let path = workspace.path("file")

        do {
            let handle = try WriteFileHandle(forFileAt: path, options: .newFile())
            #expect(try handle.write(ByteBuffer("contents".utf8)) == 8)
        }

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }

}
