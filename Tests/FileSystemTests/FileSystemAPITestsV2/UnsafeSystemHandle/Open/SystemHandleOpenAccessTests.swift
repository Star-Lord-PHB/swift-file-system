import Testing
import Foundation
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.OpenTests {

    @Test
    func `Read-only open reads but rejects writes`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        var buffer = Data(count: 5)

        try #expect(handle.read(into: buffer.mutableBytes) == 5)

        #expect(buffer == Data("Hello".utf8))
        #expect(try handle.tell() == 5)

        let error = #expect(throws: LowLevelError.self) {
            let payload = Data("nope".utf8)
            return try handle.write(contentsOf: payload.bytes)
        }

        // NOTE: The rejection surfaces as the raw platform code: EBADF on POSIX,
        // ERROR_ACCESS_DENIED on Windows.
        #if canImport(WinSDK)
        #expect(error?.systemCode == .accessDenied)
        #else
        #expect(error?.systemCode == .badFileDescriptor)
        #endif

        try handle.close()

    }


    @Test
    func `Write-only open writes but rejects reads`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))

        let payload = Data("Howdy".utf8)

        try #expect(handle.write(contentsOf: payload.bytes) == 5)

        #expect(try handle.tell() == 5)

        let error = #expect(throws: LowLevelError.self) {
            var buffer = Data(count: 1)
            _ = try handle.read(into: buffer.mutableBytes)
        }

        #if canImport(WinSDK)
        #expect(error?.systemCode == .accessDenied)
        #else
        #expect(error?.systemCode == .badFileDescriptor)
        #endif

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Howdy Swift!".utf8))

    }


    @Test
    func `Read-write open reads and writes through a shared offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readWrite()))

        var head = Data(count: 6)

        try #expect(handle.read(into: head.mutableBytes) == 6)

        #expect(head == Data("Hello ".utf8))

        let payload = Data("World!".utf8)

        try handle.write(contentsOf: payload.bytes)

        #expect(try handle.tell() == 12)

        try handle.seek(to: 0)

        var fullContents = Data(count: 12)
        _ = try handle.read(into: fullContents.mutableBytes)

        #expect(fullContents == Data("Hello World!".utf8))

        try handle.close()

    }


    @Test
    func `Append open positions every write at the file end`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Serika")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), append: true)
        )

        let firstPayload = Data(" is Cute!".utf8)

        try #expect(handle.write(contentsOf: firstPayload.bytes) == 9)

        #expect(try handle.tell() == 15)

        // NOTE: Forced append-at-end must hold even after an explicit seek: POSIX through O_APPEND,
        // Windows through an access mask that holds FILE_APPEND_DATA without FILE_WRITE_DATA.
        // Multi-handle append interleaving is covered by the FileHandle Append suite.
        try handle.seek(to: 0)

        let secondPayload = Data(" Again".utf8)

        try handle.write(contentsOf: secondPayload.bytes)

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Serika is Cute! Again".utf8))

    }


    @Test
    func `Default open follows a symlink to its target`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let handle = try UnsafeSystemHandle.open(at: link)

        var buffer = Data(count: 15)

        try #expect(handle.read(into: buffer.mutableBytes) == 15)

        #expect(buffer == Data("target contents".utf8))

        try handle.close()

    }

}
