import Testing
import Foundation
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.IOTests {

    @Test
    func `Sequential reads advance the shared offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        var head = Data(count: 5)

        try #expect(handle.read(into: head.mutableBytes) == 5)

        #expect(head == Data("Hello".utf8))
        #expect(try handle.tell() == 5)

        var tail = Data(repeating: 0xFF, count: 100)

        try #expect(handle.read(into: tail.mutableBytes) == 7)

        #expect(tail[..<7] == Data(" Swift!".utf8))
        #expect(try handle.tell() == 12)

        try handle.close()

    }


    @Test
    func `Read at EOF returns zero`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        try handle.seek(to: 0, from: .end)

        var buffer = Data(count: 4)
        let bytesRead = try handle.read(into: buffer.mutableBytes)

        #expect(bytesRead == 0)
        #expect(try handle.tell() == 3)
        #expect(buffer == Data(count: 4))

        try handle.close()

    }


    @Test
    func `Overwrite after seeks lands at the seek position`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))

        let head = Data("Write".utf8)

        try handle.write(contentsOf: head.bytes)

        #expect(try handle.tell() == 5)
        try #expect(handle.seek(to: -1, from: .current) == 4)

        let tail = Data("ing in Swift".utf8)

        try handle.write(contentsOf: tail.bytes)

        #expect(try handle.tell() == 16)

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Writing in Swift".utf8))

    }


    @Test
    func `pread reads at the given offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        var head = Data(count: 5)
        _ = try handle.read(into: head.mutableBytes)

        var word = Data(count: 5)
        let wordBytesRead = try handle.pread(into: word.mutableBytes, from: 6)

        #expect(wordBytesRead == 5)
        #expect(word == Data("Swift".utf8))

        // NOTE: POSIX pread never touches the shared offset. On a synchronous Windows handle,
        // ReadFile with an explicit OVERLAPPED offset also advances the file pointer to the end
        // of the transfer; this platform difference is raw handle semantics, high-level handles
        // track their own offsets on top of it.
        #if canImport(WinSDK)
        #expect(try handle.tell() == 11)
        #else
        #expect(try handle.tell() == 5)
        #endif

        try handle.close()

    }


    @Test
    func `pwrite writes at the given offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readWrite()))

        var head = Data(count: 5)
        _ = try handle.read(into: head.mutableBytes)

        let payload = Data("World!".utf8)
        let bytesWritten = try handle.pwrite(contentsOf: payload.bytes, to: 6)

        #expect(bytesWritten == 6)

        // NOTE: Same platform difference as pread: the shared offset stays on POSIX and moves to
        // the end of the transfer on a synchronous Windows handle.
        #if canImport(WinSDK)
        #expect(try handle.tell() == 12)
        #else
        #expect(try handle.tell() == 5)
        #endif

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hello World!".utf8))

    }


    @Test
    func `pread crossing and past EOF`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        var tail = Data(repeating: 0xFF, count: 4)
        let tailBytesRead = try handle.pread(into: tail.mutableBytes, from: 3)

        #expect(tailBytesRead == 2)
        #expect(tail[..<2] == Data("lo".utf8))

        // NOTE: Reading entirely past EOF is a platform difference at this layer: POSIX pread
        // returns zero bytes, Windows ReadFile at an OVERLAPPED offset past EOF fails with
        // ERROR_HANDLE_EOF.
        #if canImport(WinSDK)
        let error = #expect(throws: LowLevelError.self) {
            var past = Data(repeating: 0xFF, count: 4)
            _ = try handle.pread(into: past.mutableBytes, from: 10)
        }
        #expect(error?.systemCode == .handleEOF)
        #else
        var past = Data(repeating: 0xFF, count: 4)
        let pastBytesRead = try handle.pread(into: past.mutableBytes, from: 10)
        #expect(pastBytesRead == 0)
        #endif

        try handle.close()

    }


    @Test
    func `pwrite past EOF extends the file with a zero gap`() throws {

        let path = try workspace.makeFile(at: "file", contents: "AB")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))

        let payload = Data("Z".utf8)
        let bytesWritten = try handle.pwrite(contentsOf: payload.bytes, to: 4)

        #expect(bytesWritten == 1)

        try handle.close()

        #expect(
            try Data(contentsOf: URL(filePath: path.string))
                == Data("AB".utf8) + Data([0, 0]) + Data("Z".utf8)
        )

    }

}
