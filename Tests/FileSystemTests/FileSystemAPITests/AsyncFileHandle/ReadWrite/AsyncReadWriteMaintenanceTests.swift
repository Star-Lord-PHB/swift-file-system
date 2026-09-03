import Testing
import SwiftAsyncFileSystem



// NOTE: The resize error path, synchronize and their cancellation contracts are covered in
// the Write group; the tests below add the read-back a read-write handle allows.
extension AsyncFileHandleAPITests.ReadWriteTests {

    @Test
    func `Resize shrinks file and reads stop at the new EOF`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        try await handle.resize(to: 4)

        #expect(try await handle.read(fromOffset: 3, length: 3) == ByteBuffer("3".utf8))
        #expect(try await handle.read(fromOffset: 8, length: 1).isEmpty)

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("0123".utf8))

    }


    @Test
    func `Resize grows file readable as zero fill`() async throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try await AsyncReadWriteFileHandle(forFileAt: path)

        try await handle.resize(to: 6)

        #expect(try await handle.read(fromOffset: 1, length: 5) == ByteBuffer([0x62, 0x63, 0, 0, 0]))

        try await handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0]))

    }

}
