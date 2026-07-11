import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Collection Access")
    final class CollectionAccess {}

}



extension ByteBufferTest.CollectionAccess {

    @Test
    func `Collection indices and iteration match the stored bytes`() {

        let bytes = ByteBufferTest.sequentialBytes(count: 32)
        let buffer = ByteBuffer(bytes)

        #expect(buffer.startIndex == 0)
        #expect(buffer.endIndex == bytes.count)
        #expect(buffer.indices == bytes.indices)
        #expect(buffer.index(after: 4) == 5)
        #expect(buffer.index(before: 5) == 4)
        ByteBufferTest.expectBytes(buffer, equals: bytes)

    }


    @Test
    func `Subscript reads and writes single bytes`() {

        var buffer = ByteBuffer([0x00, 0x01, 0x02, 0x03] as [UInt8])

        #expect(buffer[0] == 0x00)
        #expect(buffer[3] == 0x03)

        buffer[1] = 0xAA
        buffer[3] = 0xFF

        ByteBufferTest.expectBytes(buffer, equals: [0x00, 0xAA, 0x02, 0xFF])

    }


    @Test
    func `Range subscripts expose prefix, middle, suffix, and empty slices`() {

        let bytes = ByteBufferTest.sequentialBytes(count: 24)
        let buffer = ByteBuffer(bytes)

        ByteBufferTest.expectBytes(buffer[0 ..< 6], equals: bytes[0 ..< 6])
        ByteBufferTest.expectBytes(buffer[8 ..< 16], equals: bytes[8 ..< 16])
        ByteBufferTest.expectBytes(buffer[18 ..< 24], equals: bytes[18 ..< 24])
        ByteBufferTest.expectBytes(buffer[12 ..< 12], equals: [])

    }


    @Test
    func `Collection views on empty buffers are empty`() {

        let buffer = ByteBuffer()

        #expect(buffer.startIndex == 0)
        #expect(buffer.endIndex == 0)
        #expect(buffer.indices.isEmpty)
        ByteBufferTest.expectBytes(buffer, equals: [])
        ByteBufferTest.expectBytes(buffer[0 ..< 0], equals: [])

    }


    @Test
    func `Out-of-bounds collection access traps`() async {

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer([0, 1, 2] as [UInt8])
            _ = buffer[-1]
        }

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer([0, 1, 2] as [UInt8])
            _ = buffer[3]
        }

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer([0, 1, 2] as [UInt8])
            _ = buffer[-1 ..< 1]
        }

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer([0, 1, 2] as [UInt8])
            _ = buffer[1 ..< 4]
        }

    }

}
