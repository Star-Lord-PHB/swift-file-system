import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Removal")
    final class Removal {}

}



extension ByteBufferTest.Removal {

    @Test
    func `remove(at:) removes from the beginning, middle, and end`() {

        var buffer = ByteBuffer(ByteBufferTest.sequentialBytes(count: 10))
        var expected = ByteBufferTest.sequentialBytes(count: 10)

        #expect(buffer.remove(at: 0) == expected.remove(at: 0))
        ByteBufferTest.expectBytes(buffer, equals: expected)

        #expect(buffer.remove(at: 4) == expected.remove(at: 4))
        ByteBufferTest.expectBytes(buffer, equals: expected)

        #expect(buffer.remove(at: buffer.count - 1) == expected.remove(at: expected.count - 1))
        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `removeSubrange removes prefix, middle, suffix, and empty ranges`() {

        var buffer = ByteBuffer(ByteBufferTest.sequentialBytes(count: 20))
        var expected = ByteBufferTest.sequentialBytes(count: 20)

        buffer.removeSubrange(0 ..< 3)
        expected.removeSubrange(0 ..< 3)
        ByteBufferTest.expectBytes(buffer, equals: expected)

        buffer.removeSubrange(5 ..< 9)
        expected.removeSubrange(5 ..< 9)
        ByteBufferTest.expectBytes(buffer, equals: expected)

        buffer.removeSubrange(buffer.count - 3 ..< buffer.count)
        expected.removeSubrange(expected.count - 3 ..< expected.count)
        ByteBufferTest.expectBytes(buffer, equals: expected)

        buffer.removeSubrange(2 ..< 2)
        expected.removeSubrange(2 ..< 2)
        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `removeAll drops storage by default`() {

        var buffer = ByteBuffer(ByteBufferTest.sequentialBytes(count: 16))

        buffer.removeAll()

        #expect(buffer.isEmpty)
        #expect(buffer.capacity == 0)
        ByteBufferTest.expectBytes(buffer, equals: [])

    }


    @Test
    func `removeAll can keep capacity`() {

        var buffer = ByteBuffer(ByteBufferTest.sequentialBytes(count: 16))
        let originalCapacity = buffer.capacity

        buffer.removeAll(keepingCapacity: true)

        #expect(buffer.isEmpty)
        #expect(buffer.capacity == originalCapacity)
        ByteBufferTest.expectBytes(buffer, equals: [])

    }


    @Test
    func `removeAll(where:) handles matching none, some, and all bytes`() {

        var buffer = ByteBuffer(ByteBufferTest.sequentialBytes(count: 12))

        buffer.removeAll { $0 > 200 }
        ByteBufferTest.expectBytes(buffer, equals: ByteBufferTest.sequentialBytes(count: 12))

        buffer.removeAll { $0 % 3 == 0 }
        ByteBufferTest.expectBytes(buffer, equals: [1, 2, 4, 5, 7, 8, 10, 11])

        buffer.removeAll { _ in true }
        #expect(buffer.isEmpty)
        ByteBufferTest.expectBytes(buffer, equals: [])

    }


    @Test
    func `Invalid removals trap`() async {

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer([0, 1, 2] as [UInt8])
            _ = buffer.remove(at: 3)
        }

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer([0, 1, 2] as [UInt8])
            buffer.removeSubrange(2 ..< 4)
        }

    }

}
