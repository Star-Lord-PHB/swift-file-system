import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Element Appending and Capacity")
    final class ElementAppendingAndCapacity {}

}



extension ByteBufferTest.ElementAppendingAndCapacity {

    @Test
    func `Appending single bytes grows the buffer`() {

        var buffer = ByteBuffer()
        var expected: [UInt8] = []

        for byte in ByteBufferTest.sequentialBytes(count: 80) {
            buffer.append(byte)
            expected.append(byte)
        }

        #expect(buffer.count == expected.count)
        #expect(buffer.capacity >= expected.count)
        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `Appending contents accepts arrays, non-contiguous collections, and generated sequences`() {

        var buffer = ByteBuffer([0x00] as [UInt8])
        var expected = [0x00] as [UInt8]

        let array = [0x01, 0x02, 0x03] as [UInt8]
        buffer.append(contentsOf: array)
        expected.append(contentsOf: array)

        let nonContiguous = ByteBufferTest.NonContiguousBytes([0x04, 0x05, 0x06])
        buffer.append(contentsOf: nonContiguous)
        expected.append(contentsOf: nonContiguous)

        let generated = ByteBufferTest.GeneratedBytes(count: 40, start: 0x20)
        buffer.append(contentsOf: generated)
        expected.append(contentsOf: ByteBufferTest.sequentialBytes(count: 40, startingAt: 0x20))

        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `append(bytes:) appends directly from sequences`() {

        var buffer = ByteBuffer([0xAA] as [UInt8])

        buffer.append(bytes: ByteBufferTest.GeneratedBytes(count: 5, start: 0x10))
        buffer.append(bytes: [] as [UInt8])

        ByteBufferTest.expectBytes(buffer, equals: [0xAA, 0x10, 0x11, 0x12, 0x13, 0x14])

    }


    @Test
    func `Appending empty sequences is a no-op`() {

        var buffer = ByteBuffer([1, 2, 3] as [UInt8])
        let originalCapacity = buffer.capacity

        buffer.append(contentsOf: [] as [UInt8])
        buffer.append(bytes: ByteBufferTest.GeneratedBytes(count: 0))

        ByteBufferTest.expectBytes(buffer, equals: [1, 2, 3])
        #expect(buffer.capacity == originalCapacity)

    }


    @Test
    func `Appending empty sequence to a empty buffer is a no-op`() {

        var buffer = ByteBuffer()
        let originalCapacity = buffer.capacity

        buffer.append(contentsOf: [] as [UInt8])
        buffer.append(bytes: ByteBufferTest.GeneratedBytes(count: 0))

        #expect(buffer.isEmpty)
        #expect(buffer.capacity == originalCapacity)

    }


    @Test
    func `Appending to a unique slice-backed buffer preserves bytes when rebasing`() {

        var buffer = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 32)

        buffer.append(0xFF)

        ByteBufferTest.expectBytes(buffer, equals: ByteBufferTest.sequentialBytes(count: 24, startingAt: 8) + [0xFF])
        #expect(buffer.startOffsetInStorage == 0)

    }


    @Test
    func `reserveCapacity preserves bytes and never reduces capacity`() {

        var buffer = ByteBuffer([1, 2, 3] as [UInt8])
        let originalCapacity = buffer.capacity

        buffer.reserveCapacity(128)

        #expect(buffer.capacity >= 128)
        ByteBufferTest.expectBytes(buffer, equals: [1, 2, 3])

        buffer.reserveCapacity(2)

        #expect(buffer.capacity >= originalCapacity)
        #expect(buffer.capacity >= 128)
        ByteBufferTest.expectBytes(buffer, equals: [1, 2, 3])

    }


    @Test
    func `shrinkToFit releases excess capacity without changing bytes`() {

        var buffer = ByteBuffer(capacity: 256)
        buffer.append(contentsOf: [1, 2, 3] as [UInt8])

        buffer.shrinkToFit()

        #expect(buffer.capacity >= buffer.count)
        #expect(buffer.capacity < 256)
        ByteBufferTest.expectBytes(buffer, equals: [1, 2, 3])

    }


    @Test
    func `shrinkToFit on an empty buffer releases storage`() {

        var buffer = ByteBuffer(capacity: 64)

        buffer.shrinkToFit()

        #expect(buffer.isEmpty)
        #expect(buffer.capacity == 0)

    }

}
