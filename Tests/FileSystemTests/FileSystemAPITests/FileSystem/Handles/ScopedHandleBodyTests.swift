import SystemPackage
import Testing
import SwiftFileSystem



// After the body returns, the wrapper closes the handle and returns the body's result.
// The probe is captured inside the body and checked once the wrapper has returned.
extension FileSystemAPITests.HandlesTests {

    @Test
    func `Reading wrapper returns the body result and releases the handle`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")

        let (probe, contents) = try fileSystem.withFileHandle(forReadingAt: path) { handle in
            let probe = try handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
            return (probe, try handle.read(fromOffset: 0, length: 8))
        }

        #expect(contents == ByteBuffer("contents".utf8))
        #expect(probe.isReleased)

    }


    @Test
    func `Writing wrapper returns the body result and releases the handle`() throws {

        let path = try workspace.makeFile(at: "file")

        let (probe, written) = try fileSystem.withFileHandle(forWritingAt: path) { handle in
            let probe = try handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
            return (probe, try handle.write(ByteBuffer("contents".utf8), toOffset: 0))
        }

        #expect(written == 8)
        #expect(probe.isReleased)

    }


    @Test
    func `Appending wrapper returns the body result and releases the handle`() throws {

        let path = try workspace.makeFile(at: "file")

        let (probe, appended) = try fileSystem.withFileHandle(forAppendingAt: path) { handle in
            let probe = try handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
            return (probe, try handle.append(ByteBuffer("contents".utf8)))
        }

        #expect(appended == 8)
        #expect(probe.isReleased)

    }


    @Test
    func `Updating wrapper returns the body result and releases the handle`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")

        let (probe, contents) = try fileSystem.withFileHandle(forUpdatingAt: path) { handle in
            let probe = try handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
            return (probe, try handle.read(fromOffset: 0, length: 8))
        }

        #expect(contents == ByteBuffer("contents".utf8))
        #expect(probe.isReleased)

    }


    @Test
    func `Directory wrapper returns the body result and releases the handle`() throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [:]
            ]
        )

        let (probe, entries) = try fileSystem.withDirHandle(at: path) { handle in
            let probe = try handle.withUnsafeSystemHandle {
                try Support.SystemHandleProbe(capturing: $0)
            }
            return (probe, try handle.directEntries())
        }

        #expect(entries.map(\.name).sorted() == ["file", "subdir"])
        #expect(probe.isReleased)

    }


    @Test
    func `Reading wrapper returns a non-copyable body result`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")

        let result = try fileSystem.withFileHandle(forReadingAt: path) { handle in
            NonCopyableResult(contents: try handle.read(fromOffset: 0, length: 8))
        }

        #expect(result.contents == ByteBuffer("contents".utf8))

    }

}



// A body error must reach the caller unchanged — the wrapper closes the handle on the way
// out but must not replace, wrap or swallow the error.
extension FileSystemAPITests.HandlesTests {

    @Test
    func `Reading wrapper rethrows the body error and releases the handle`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        var probe: Support.SystemHandleProbe?

        #expect(throws: BodyError()) {
            try fileSystem.withFileHandle(forReadingAt: path) { handle in
                probe = try handle.withUnsafeSystemHandle {
                    try Support.SystemHandleProbe(capturing: $0)
                }
                throw BodyError()
            }
        }

        #expect(try #require(probe).isReleased)

    }


    @Test
    func `Writing wrapper rethrows the body error and releases the handle`() throws {

        let path = try workspace.makeFile(at: "file")
        var probe: Support.SystemHandleProbe?

        #expect(throws: BodyError()) {
            try fileSystem.withFileHandle(forWritingAt: path) { handle in
                probe = try handle.withUnsafeSystemHandle {
                    try Support.SystemHandleProbe(capturing: $0)
                }
                throw BodyError()
            }
        }

        #expect(try #require(probe).isReleased)

    }


    @Test
    func `Appending wrapper rethrows the body error and releases the handle`() throws {

        let path = try workspace.makeFile(at: "file")
        var probe: Support.SystemHandleProbe?

        #expect(throws: BodyError()) {
            try fileSystem.withFileHandle(forAppendingAt: path) { handle in
                probe = try handle.withUnsafeSystemHandle {
                    try Support.SystemHandleProbe(capturing: $0)
                }
                throw BodyError()
            }
        }

        #expect(try #require(probe).isReleased)

    }


    @Test
    func `Updating wrapper rethrows the body error and releases the handle`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")
        var probe: Support.SystemHandleProbe?

        #expect(throws: BodyError()) {
            try fileSystem.withFileHandle(forUpdatingAt: path) { handle in
                probe = try handle.withUnsafeSystemHandle {
                    try Support.SystemHandleProbe(capturing: $0)
                }
                throw BodyError()
            }
        }

        #expect(try #require(probe).isReleased)

    }


    @Test
    func `Directory wrapper rethrows the body error and releases the handle`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        var probe: Support.SystemHandleProbe?

        #expect(throws: BodyError()) {
            try fileSystem.withDirHandle(at: path) { handle in
                probe = try handle.withUnsafeSystemHandle {
                    try Support.SystemHandleProbe(capturing: $0)
                }
                throw BodyError()
            }
        }

        #expect(try #require(probe).isReleased)

    }

}



// Data written inside the body must be on disk once the wrapper has returned.
extension FileSystemAPITests.HandlesTests {

    @Test
    func `Writing wrapper commits written data`() throws {

        let path = try workspace.makeFile(at: "file")

        try fileSystem.withFileHandle(forWritingAt: path) { handle in
            _ = try handle.write(ByteBuffer("contents".utf8), toOffset: 0)
        }

        #expect(try capturedContents(at: path) == ByteBuffer("contents".utf8))

    }


    @Test
    func `Appending wrapper commits appended data`() throws {

        let path = try workspace.makeFile(at: "file", contents: "existing ")

        try fileSystem.withFileHandle(forAppendingAt: path) { handle in
            _ = try handle.append(ByteBuffer("contents".utf8))
        }

        #expect(try capturedContents(at: path) == ByteBuffer("existing contents".utf8))

    }


    @Test
    func `Updating wrapper commits written data`() throws {

        let path = try workspace.makeFile(at: "file", contents: "existing contents")

        try fileSystem.withFileHandle(forUpdatingAt: path) { handle in
            _ = try handle.write(ByteBuffer("replaced".utf8), toOffset: 0)
        }

        #expect(try capturedContents(at: path) == ByteBuffer("replaced contents".utf8))

    }

}
