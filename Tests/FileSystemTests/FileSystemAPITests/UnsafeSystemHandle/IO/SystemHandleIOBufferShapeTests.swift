import Testing
import Foundation
import SwiftFileSystem



// Buffer-shape coverage for the I/O primitives. The rest of the group reads and writes through
// the span overloads, so this file pins the remaining shapes: the rebased-slice pointer
// overloads, the empty-buffer edge of the raw-pointer primitives (nil base address), and the
// span-specific contracts - reusing one span across reads and the consuming forwarding.
extension UnsafeSystemHandleAPITests.IOTests {

    @Test
    func `Read into a buffer slice lands in the slice`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        var buffer = Data(repeating: 0xFF, count: 9)
        let bytesRead = try buffer.withUnsafeMutableBytes { try handle.read(into: $0[2..<7]) }

        #expect(bytesRead == 5)
        #expect(buffer == Data([0xFF, 0xFF]) + Data("Hello".utf8) + Data([0xFF, 0xFF]))

        try handle.close()

    }


    @Test
    func `Write from a buffer slice writes only the slice`() throws {

        let path = workspace.path("out")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .createIfMissing)
        )

        let payload = Data("XXHelloYY".utf8)
        let bytesWritten = try payload.withUnsafeBytes { try handle.write(contentsOf: $0[2..<7]) }

        #expect(bytesWritten == 5)

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hello".utf8))

    }


    @Test
    func `Same span reused across sequential reads`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        var buffer = Data(repeating: 0xFF, count: 4)
        var span = buffer.mutableBytes

        let firstBytesRead = try handle.read(into: &span)
        let secondBytesRead = try handle.read(into: &span)

        #expect(firstBytesRead == 4)
        #expect(secondBytesRead == 4)
        #expect(buffer == Data("o Sw".utf8))
        #expect(try handle.tell() == 8)

        try handle.close()

    }


    @Test
    func `Consuming span overload writes into the underlying storage`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        var buffer = Data(repeating: 0xFF, count: 5)

        try #expect(handle.read(into: buffer.mutableBytes) == 5)

        #expect(buffer == Data("Hello".utf8))
        #expect(try handle.tell() == 5)

        try handle.close()

    }


    @Test
    func `Empty buffer read and write transfer zero bytes`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readWrite()))

        var emptyIn = Data()
        let bytesRead = try emptyIn.withUnsafeMutableBytes { try handle.read(into: $0) }
        let bytesWritten = try Data().withUnsafeBytes { try handle.write(contentsOf: $0) }

        #expect(bytesRead == 0)
        #expect(bytesWritten == 0)
        #expect(try handle.tell() == 0)

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("abc".utf8))

    }

}
