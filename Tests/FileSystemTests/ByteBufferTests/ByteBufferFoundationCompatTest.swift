import Foundation
import SwiftFileSystemFoundationCompat
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Foundation Interop")
    final class FoundationInterop {}

}



extension ByteBufferTest.FoundationInterop {

    @Test
    func `DataProtocol regions contain the buffer itself`() {

        let buffer = ByteBuffer([1, 2, 3] as [UInt8])
        let regions = Array(buffer.regions)

        #expect(regions.count == 1)
        ByteBufferTest.expectBytes(regions[0], equals: [1, 2, 3])

    }


    @Test
    func `data creates Foundation Data with the same bytes`() {

        let bytes = ByteBufferTest.sequentialBytes(count: 32)
        let buffer = ByteBuffer(bytes)

        #expect(buffer.data == Data(bytes))

    }


    @Test
    func `ContiguousBytes exposes the readable bytes`() {

        let bytes = ByteBufferTest.sequentialBytes(count: 16)
        let buffer = ByteBuffer(bytes)

        let exposed = buffer.withUnsafeBytes { rawBytes in
            Array(rawBytes)
        }

        #expect(exposed == bytes)

    }


    @Test
    func `Foundation string decoding reads valid encodings`() {

        let string = "Hello ByteBuffer"
        let data = string.data(using: .utf16LittleEndian)!
        var reader = ByteBuffer(data).reader()

        #expect(reader.readString(upTo: data.count, encoding: .utf16LittleEndian) == string)
        #expect(reader.remainingBytes == 0)

    }


    @Test
    func `Foundation string decoding returns nil for invalid and empty byte reads`() {

        var invalidReader = ByteBuffer([0xFF] as [UInt8]).reader()

        #expect(invalidReader.readString(upTo: 1, encoding: .utf8) == nil)
        #expect(invalidReader.remainingBytes == 0)

        var emptyReader = ByteBuffer().reader()
        #expect(emptyReader.readString(upTo: 1, encoding: .utf8) == nil)
        #expect(emptyReader.readOffset == 0)

    }

}
