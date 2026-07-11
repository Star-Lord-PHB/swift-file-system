import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("COW")
    final class COW {}

}



extension ByteBufferTest.COW {

    @Test
    func `Subscript mutation uses COW`() throws {

        let original = ByteBuffer([0, 1, 2, 3] as [UInt8])
        var copy = original

        try #require(original.storage === copy.storage)

        copy[2] = 0xAA

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: [0, 1, 2, 3])
        ByteBufferTest.expectBytes(copy, equals: [0, 1, 0xAA, 3])

    }


    @Test
    func `append(_:) uses COW`() throws {

        let original = ByteBuffer([0, 1, 2] as [UInt8])
        var copy = original

        try #require(original.storage === copy.storage)

        copy.append(0xAA)

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: [0, 1, 2])
        ByteBufferTest.expectBytes(copy, equals: [0, 1, 2, 0xAA])

    }


    @Test
    func `append(contentsOf:) uses COW`() throws {

        let original = ByteBuffer([0, 1, 2] as [UInt8])
        var copy = original

        try #require(original.storage === copy.storage)

        copy.append(contentsOf: [0xBB, 0xCC] as [UInt8])

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: [0, 1, 2])
        ByteBufferTest.expectBytes(copy, equals: [0, 1, 2, 0xBB, 0xCC])

    }


    @Test
    func `replaceSubrange(_:with:) uses COW`() throws {

        let original = ByteBuffer(ByteBufferTest.sequentialBytes(count: 10))
        var copy = original
        var expected = ByteBufferTest.sequentialBytes(count: 10)

        try #require(original.storage === copy.storage)

        copy.replaceSubrange(2 ..< 5, with: [0xAA, 0xBB] as [UInt8])
        expected.replaceSubrange(2 ..< 5, with: [0xAA, 0xBB] as [UInt8])

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: ByteBufferTest.sequentialBytes(count: 10))
        ByteBufferTest.expectBytes(copy, equals: expected)

    }


    @Test
    func `removeSubrange(_:) uses COW`() throws {

        let original = ByteBuffer(ByteBufferTest.sequentialBytes(count: 10))
        var copy = original
        var expected = ByteBufferTest.sequentialBytes(count: 10)

        try #require(original.storage === copy.storage)

        copy.removeSubrange(4 ..< 6)
        expected.removeSubrange(4 ..< 6)

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: ByteBufferTest.sequentialBytes(count: 10))
        ByteBufferTest.expectBytes(copy, equals: expected)

    }


    @Test
    func `store(rawBytesOf:toOffset:) uses COW`() throws {

        let original = ByteBuffer([0, 1, 2, 3] as [UInt8])
        var copy = original

        try #require(original.storage === copy.storage)

        copy.store(rawBytesOf: 0xAA as UInt8, toOffset: 0)

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: [0, 1, 2, 3])
        ByteBufferTest.expectBytes(copy, equals: [0xAA, 1, 2, 3])

    }


    @Test
    func `store(bytes:toOffset:) uses COW`() throws {

        let original = ByteBuffer([0, 1, 2, 3] as [UInt8])
        var copy = original

        try #require(original.storage === copy.storage)

        copy.store(bytes: [0xBB, 0xCC] as [UInt8], toOffset: 2)

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: [0, 1, 2, 3])
        ByteBufferTest.expectBytes(copy, equals: [0, 1, 0xBB, 0xCC])

    }


    @Test
    func `Subscript mutation of a shared slice-backed copy uses COW and rebases storage`() throws {

        let sourceBytes = ByteBufferTest.sequentialBytes(count: 32)
        let source = ByteBuffer(sourceBytes)
        var copy = ByteBuffer(source[8 ..< 20])

        try #require(source.storage === copy.storage)

        copy[0] = 0xFF

        #expect(copy.storage !== source.storage)
        #expect(copy.startOffsetInStorage == 0)
        ByteBufferTest.expectBytes(source, equals: sourceBytes)
        ByteBufferTest.expectBytes(copy, equals: [0xFF] + Array(sourceBytes[9 ..< 20]))

    }


    @Test
    func `Appending to a shared slice-backed copy uses COW and rebases storage`() throws {

        let sourceBytes = ByteBufferTest.sequentialBytes(count: 32)
        let source = ByteBuffer(sourceBytes)
        var copy = ByteBuffer(source[8 ..< 20])

        try #require(source.storage === copy.storage)

        copy.append(0xEE)

        #expect(copy.storage !== source.storage)
        #expect(copy.startOffsetInStorage == 0)
        ByteBufferTest.expectBytes(source, equals: sourceBytes)
        ByteBufferTest.expectBytes(copy, equals: Array(sourceBytes[8 ..< 20]) + [0xEE])

    }


    @Test
    func `Replacing a shared slice-backed copy uses COW and rebases storage`() throws {

        let sourceBytes = ByteBufferTest.sequentialBytes(count: 32)
        let source = ByteBuffer(sourceBytes)
        var copy = ByteBuffer(source[8 ..< 20])
        var expected = Array(sourceBytes[8 ..< 20])

        try #require(source.storage === copy.storage)

        copy.replaceSubrange(2 ..< 6, with: [0xAA, 0xBB] as [UInt8])
        expected.replaceSubrange(2 ..< 6, with: [0xAA, 0xBB] as [UInt8])

        #expect(copy.storage !== source.storage)
        #expect(copy.startOffsetInStorage == 0)
        ByteBufferTest.expectBytes(source, equals: sourceBytes)
        ByteBufferTest.expectBytes(copy, equals: expected)

    }

}
