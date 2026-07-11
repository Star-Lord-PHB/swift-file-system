import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Equality and Hashing")
    final class EqualityAndHashing {}

}



extension ByteBufferTest.EqualityAndHashing {

    @Test
    func `Equality compares bytes rather than storage identity`() {

        let bytes = ByteBufferTest.sequentialBytes(count: 16)
        let first = ByteBuffer(bytes)
        let second = ByteBuffer(bytes)
        let sliceBacked = ByteBuffer(ByteBuffer([0xFF] + bytes + [0xEE])[1 ..< 17])

        #expect(ByteBuffer() == ByteBuffer())
        #expect(first == second)
        #expect(first == sliceBacked)
        #expect(first.storage !== second.storage)
        #expect(first.storage !== sliceBacked.storage)

    }


    @Test
    func `Inequality detects different counts and different bytes`() {

        #expect(ByteBuffer() != ByteBuffer([0] as [UInt8]))
        #expect(ByteBuffer([1, 2, 3] as [UInt8]) != ByteBuffer([1, 2, 3, 4] as [UInt8]))
        #expect(ByteBuffer([1, 2, 3] as [UInt8]) != ByteBuffer([1, 9, 3] as [UInt8]))

        let source = ByteBuffer([0, 1, 2, 3, 4] as [UInt8])
        #expect(ByteBuffer(source[1 ..< 4]) != ByteBuffer(source[0 ..< 3]))

    }


    @Test
    func `Hashable treats equal buffers as the same key`() {

        let bytes = ByteBufferTest.sequentialBytes(count: 20)
        let direct = ByteBuffer(bytes)
        let copied = ByteBuffer(bytes)
        let sliceBacked = ByteBuffer(ByteBuffer([0xAA] + bytes + [0xBB])[1 ..< 21])

        #expect(direct.hashValue == copied.hashValue)
        #expect(direct.hashValue == sliceBacked.hashValue)

        let set = Set([direct, copied, sliceBacked, ByteBuffer([0xFF] as [UInt8])])

        #expect(set.count == 2)
        #expect(set.contains(direct))
        #expect(set.contains(ByteBuffer([0xFF] as [UInt8])))

    }

}
