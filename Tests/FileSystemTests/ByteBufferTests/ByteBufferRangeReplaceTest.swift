import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Range Replacement")
    final class RangeReplacement {}

}



extension ByteBufferTest.RangeReplacement {

    @Test
    func `Inserting single bytes works at the beginning, middle, and end`() {

        var buffer = ByteBuffer([0, 1, 2, 3] as [UInt8])
        var expected = [0, 1, 2, 3] as [UInt8]

        buffer.insert(0xAA, at: 0)
        expected.insert(0xAA, at: 0)
        ByteBufferTest.expectBytes(buffer, equals: expected)

        buffer.insert(0xBB, at: 3)
        expected.insert(0xBB, at: 3)
        ByteBufferTest.expectBytes(buffer, equals: expected)

        buffer.insert(0xCC, at: buffer.endIndex)
        expected.insert(0xCC, at: expected.endIndex)
        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `Inserting collections works at the beginning, middle, and end`() {

        var buffer = ByteBuffer([0, 1, 2, 3] as [UInt8])
        var expected = [0, 1, 2, 3] as [UInt8]

        let prefix = [0xA0, 0xA1] as [UInt8]
        buffer.insert(contentsOf: prefix, at: 0)
        expected.insert(contentsOf: prefix, at: 0)
        ByteBufferTest.expectBytes(buffer, equals: expected)

        let middle = ByteBufferTest.NonContiguousBytes([0xB0, 0xB1, 0xB2])
        buffer.insert(contentsOf: middle, at: 3)
        expected.insert(contentsOf: middle, at: 3)
        ByteBufferTest.expectBytes(buffer, equals: expected)

        let suffix = [0xC0, 0xC1] as [UInt8]
        buffer.insert(contentsOf: suffix, at: buffer.endIndex)
        expected.insert(contentsOf: suffix, at: expected.endIndex)
        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `Replacing with the same count overwrites in place`() {

        var buffer = ByteBuffer(ByteBufferTest.sequentialBytes(count: 12))
        var expected = ByteBufferTest.sequentialBytes(count: 12)

        buffer.replaceSubrange(4 ..< 8, with: [0xF0, 0xF1, 0xF2, 0xF3] as [UInt8])
        expected.replaceSubrange(4 ..< 8, with: [0xF0, 0xF1, 0xF2, 0xF3] as [UInt8])

        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `Replacing with fewer bytes shrinks and moves the tail`() {

        var buffer = ByteBuffer(ByteBufferTest.sequentialBytes(count: 16))
        var expected = ByteBufferTest.sequentialBytes(count: 16)

        buffer.replaceSubrange(5 ..< 12, with: ByteBufferTest.NonContiguousBytes([0xAA, 0xBB]))
        expected.replaceSubrange(5 ..< 12, with: [0xAA, 0xBB] as [UInt8])

        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `Replacing with more bytes grows and moves the tail`() {

        var buffer = ByteBuffer(ByteBufferTest.sequentialBytes(count: 16))
        var expected = ByteBufferTest.sequentialBytes(count: 16)

        let replacement = ByteBufferTest.NonContiguousBytes([0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5])
        buffer.replaceSubrange(4 ..< 6, with: replacement)
        expected.replaceSubrange(4 ..< 6, with: replacement)

        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `Replacing an empty range inserts bytes`() {

        var buffer = ByteBuffer([0, 1, 2, 3] as [UInt8])
        var expected = [0, 1, 2, 3] as [UInt8]

        buffer.replaceSubrange(2 ..< 2, with: [0xAA, 0xBB] as [UInt8])
        expected.replaceSubrange(2 ..< 2, with: [0xAA, 0xBB] as [UInt8])

        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `Replacing the whole range handles non-empty and empty replacements`() {

        var buffer = ByteBuffer([0, 1, 2, 3] as [UInt8])

        buffer.replaceSubrange(buffer.startIndex ..< buffer.endIndex, with: [0xAA, 0xBB] as [UInt8])
        ByteBufferTest.expectBytes(buffer, equals: [0xAA, 0xBB])

        buffer.replaceSubrange(buffer.startIndex ..< buffer.endIndex, with: [] as [UInt8])
        #expect(buffer.isEmpty)
        ByteBufferTest.expectBytes(buffer, equals: [])

    }


    @Test
    func `Replacing a range in a unique slice-backed buffer preserves the slice tail`() {

        var buffer = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 16)

        buffer.replaceSubrange(2 ..< 4, with: [0xAA] as [UInt8])

        ByteBufferTest.expectBytes(buffer, equals: [8, 9, 0xAA, 12, 13, 14, 15])

    }


    @Test
    func `Replacing a unique slice-backed buffer with more bytes preserves contents`() {

        var buffer = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 12)
        let replacement = ByteBufferTest.sequentialBytes(count: 10, startingAt: 0xA0)

        buffer.replaceSubrange(2 ..< 2, with: replacement)

        ByteBufferTest.expectBytes(buffer, equals: [8, 9] + replacement + [10, 11])

    }


    @Test
    func `Invalid replacement ranges trap`() async {

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer([0, 1, 2] as [UInt8])
            buffer.replaceSubrange(-1 ..< 1, with: [] as [UInt8])
        }

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer([0, 1, 2] as [UInt8])
            buffer.replaceSubrange(1 ..< 4, with: [] as [UInt8])
        }

    }

}
