import Testing
import Foundation
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.OpenTests {

    @Test
    func `Read-only open reads but rejects writes`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        var buffer = Data(count: 5)
        let bytesRead = try buffer.withUnsafeMutableBytes { try handle.read(into: $0) }

        #expect(bytesRead == 5)
        #expect(buffer == Data("Hello".utf8))
        #expect(try handle.tell() == 5)

        let error = #expect(throws: LowLevelError.self) {
            try Data("nope".utf8).withUnsafeBytes { try handle.write(contentsOf: $0) }
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

        let bytesWritten = try Data("Howdy".utf8).withUnsafeBytes { try handle.write(contentsOf: $0) }

        #expect(bytesWritten == 5)
        #expect(try handle.tell() == 5)

        let error = #expect(throws: LowLevelError.self) {
            var buffer = Data(count: 1)
            _ = try buffer.withUnsafeMutableBytes { try handle.read(into: $0) }
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

        var buffer = Data(count: 6)
        let bytesRead = try buffer.withUnsafeMutableBytes { try handle.read(into: $0) }

        #expect(bytesRead == 6)
        #expect(buffer == Data("Hello ".utf8))

        _ = try Data("World!".utf8).withUnsafeBytes { try handle.write(contentsOf: $0) }

        #expect(try handle.tell() == 12)

        try handle.seek(to: 0)

        var fullContents = Data(count: 12)
        _ = try fullContents.withUnsafeMutableBytes { try handle.read(into: $0) }

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

        let bytesWritten = try Data(" is Cute!".utf8).withUnsafeBytes { try handle.write(contentsOf: $0) }

        #expect(bytesWritten == 9)
        #expect(try handle.tell() == 15)

        // NOTE: Forced append-at-end must hold even after an explicit seek: POSIX through O_APPEND,
        // Windows through an access mask that holds FILE_APPEND_DATA without FILE_WRITE_DATA.
        // Multi-handle append interleaving is covered by the FileHandle Append suite.
        try handle.seek(to: 0)
        _ = try Data(" Again".utf8).withUnsafeBytes { try handle.write(contentsOf: $0) }

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Serika is Cute! Again".utf8))

    }


    @Test
    func `Default open follows a symlink to its target`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let handle = try UnsafeSystemHandle.open(at: link)

        var buffer = Data(count: 15)
        let bytesRead = try buffer.withUnsafeMutableBytes { try handle.read(into: $0) }

        #expect(bytesRead == 15)
        #expect(buffer == Data("target contents".utf8))

        try handle.close()

    }

}
