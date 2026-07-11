import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Initialization")
    final class Initialization {}

}



extension ByteBufferTest.Initialization {

    @Test
    func `Empty initializer creates an empty buffer`() {

        let buffer = ByteBuffer()

        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(buffer.capacity == 0)

    }


    @Test
    func `Count initializer zero-fills bytes`() {

        let buffer = ByteBuffer(count: 12)

        #expect(buffer.count == 12)
        #expect(buffer.capacity == 12)
        ByteBufferTest.expectBytes(buffer, equals: Array(repeating: 0, count: 12))

    }


    @Test
    func `Zero count initializers are empty`() {

        let counted = ByteBuffer(count: 0)
        let repeated = ByteBuffer(repeating: 0xAB, count: 0)

        #expect(counted.isEmpty)
        #expect(repeated.isEmpty)
        #expect(counted.capacity == 0)
        #expect(repeated.capacity == 0)

    }


    @Test
    func `Capacity initializer reserves storage without changing count`() {

        let buffer = ByteBuffer(capacity: 12)

        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(buffer.capacity == 12)
        #expect(buffer.storage.buffer.baseAddress != nil)

    }


    @Test
    func `Repeating initializer fills bytes`() {

        let buffer = ByteBuffer(repeating: 0xAB, count: 12)

        #expect(buffer.count == 12)
        ByteBufferTest.expectBytes(buffer, equals: Array(repeating: 0xAB, count: 12))

    }


    @Test
    func `Sequence initializer accepts contiguous, empty, and single-pass sequences`() {

        ByteBufferTest.expectBytes(ByteBuffer([1, 2, 3]), equals: [1, 2, 3])
        ByteBufferTest.expectBytes(ByteBuffer([]), equals: [])

        let generated = ByteBufferTest.GeneratedBytes(count: 40, start: 0x20)
        ByteBufferTest.expectBytes(ByteBuffer(generated), equals: ByteBufferTest.sequentialBytes(count: 40, startingAt: 0x20))

    }


    @Test
    func `Array literal initializer preserves bytes`() {

        let buffer: ByteBuffer = [0x01, 0x02, 0xFE, 0xFF]

        ByteBufferTest.expectBytes(buffer, equals: [0x01, 0x02, 0xFE, 0xFF])

    }


    @Test
    func `Copy initializer shares storage until mutation`() {

        let source = ByteBuffer(ByteBufferTest.sequentialBytes(count: 16))
        var copy = ByteBuffer(source)

        #expect(source.storage === copy.storage)
        #expect(source.startOffsetInStorage == copy.startOffsetInStorage)
        ByteBufferTest.expectBytes(copy, equals: source)

        copy[0] = 0xFF

        #expect(source.storage !== copy.storage)
        ByteBufferTest.expectBytes(source, equals: ByteBufferTest.sequentialBytes(count: 16))
        ByteBufferTest.expectBytes(copy, equals: [0xFF] + ByteBufferTest.sequentialBytes(count: 15, startingAt: 1))

    }


    @Test
    func `Slice initializer shares storage and exposes only the slice`() {

        let sourceBytes = ByteBufferTest.sequentialBytes(count: 32)
        let source = ByteBuffer(sourceBytes)
        let sliceRange = 8 ..< 20
        let buffer = ByteBuffer(source[sliceRange])

        #expect(source.storage === buffer.storage)
        #expect(buffer.startOffsetInStorage == sliceRange.lowerBound)
        #expect(buffer.count == sliceRange.count)
        ByteBufferTest.expectBytes(buffer, equals: sourceBytes[sliceRange])

    }


    @Test
    func `Empty slice initializer creates an empty buffer`() {

        let source = ByteBuffer(ByteBufferTest.sequentialBytes(count: 8))
        let buffer = ByteBuffer(source[4 ..< 4])

        #expect(buffer.isEmpty)
        #expect(buffer.capacity == 0)
        #expect(buffer.startOffsetInStorage == 0)

    }


    @Test
    func `Negative initializer arguments trap`() async {

        await #expect(processExitsWith: .failure) {
            _ = ByteBuffer(count: -1)
        }

        await #expect(processExitsWith: .failure) {
            _ = ByteBuffer(capacity: -1)
        }

        await #expect(processExitsWith: .failure) {
            _ = ByteBuffer(repeating: 0, count: -1)
        }

    }

}
