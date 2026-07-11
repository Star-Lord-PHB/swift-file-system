import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Unsafe Pointers and Spans")
    final class UnsafePointersAndSpans {}

}



extension ByteBufferTest.UnsafePointersAndSpans {

    @Test
    func `Unsafe scoped pointer exposes readable bytes`() {

        let expected = ByteBufferTest.sequentialBytes(count: 16)
        let buffer = ByteBuffer(expected)

        buffer.withUnsafeBufferPointer { pointer in
            ByteBufferTest.expectBytes(pointer, equals: expected)
        }

        buffer.withUnsafeBytes { bytes in
            ByteBufferTest.expectBytes(bytes, equals: expected)
        }

        let contiguous = buffer.withContiguousStorageIfAvailable { pointer in
            Array(pointer)
        }

        #expect(contiguous == expected)

    }


    @Test
    func `Unsafe scoped mutable pointer mutates bytes`() {

        var buffer = ByteBuffer([0, 1, 2, 3] as [UInt8])

        buffer.withUnsafeMutableBufferPointer { pointer in
            pointer[1] = 0xAA
        }

        buffer.withUnsafeMutableBytes { bytes in
            bytes[3] = 0xFF
        }

        let contiguous = buffer.withContiguousMutableStorageIfAvailable { pointer in
            pointer[0] = 0xEE
            return Array(pointer)
        }

        #expect(contiguous == [0xEE, 0xAA, 2, 0xFF] as [UInt8])
        ByteBufferTest.expectBytes(buffer, equals: [0xEE, 0xAA, 2, 0xFF])

    }


    @Test
    func `Unsafe scoped mutable pointer uses COW`() throws {

        let original = ByteBuffer([0, 1, 2] as [UInt8])
        var copy = original

        try #require(original.storage === copy.storage)

        copy.withUnsafeMutableBufferPointer { pointer in
            pointer[0] = 0xAA
        }

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: [0, 1, 2])
        ByteBufferTest.expectBytes(copy, equals: [0xAA, 1, 2])

    }


    @Test
    func `Unsafe scoped mutable pointer mutates unique slice-backed buffers`() async {

        await #expect(processExitsWith: .success) {
            var buffer = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 12)

            buffer.withUnsafeMutableBufferPointer { pointer in
                pointer[0] = 0xAA
            }

            ByteBufferTest.expectBytes(buffer, equals: [0xAA, 9, 10, 11])
        }

    }


    @Test
    func `Unsafe scoped mutable raw pointer mutates unique slice-backed buffers`() async {

        await #expect(processExitsWith: .success) {
            var buffer = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 12)

            buffer.withUnsafeMutableBytes { bytes in
                bytes[1] = 0xBB
            }

            ByteBufferTest.expectBytes(buffer, equals: [8, 0xBB, 10, 11])
        }

    }


    @Test
    func `Borrowed span views expose readable bytes`() {

        let expected = ByteBufferTest.sequentialBytes(count: 12)
        let buffer = ByteBuffer(expected)

        let span = buffer.span
        #expect(span.count == expected.count)
        for index in expected.indices {
            #expect(span[index] == expected[index])
        }

        buffer.bytes.withUnsafeBytes { bytes in
            ByteBufferTest.expectBytes(bytes, equals: expected)
        }

    }


    @Test
    func `Mutable span view mutates bytes and uses COW`() throws {

        let original = ByteBuffer([0, 1, 2, 3] as [UInt8])
        var copy = original

        try #require(original.storage === copy.storage)

        var span = copy.mutableSpan
        span[1] = 0xAA

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: [0, 1, 2, 3])
        ByteBufferTest.expectBytes(copy, equals: [0, 0xAA, 2, 3])

    }


    @Test
    func `Mutable raw-byte span view mutates bytes and uses COW`() throws {

        let original = ByteBuffer([0, 1, 2, 3] as [UInt8])
        var copy = original

        try #require(original.storage === copy.storage)

        var rawBytes = copy.mutableBytes
        rawBytes.withUnsafeMutableBytes { bytes in
            bytes[3] = 0xFF
        }

        #expect(original.storage !== copy.storage)
        ByteBufferTest.expectBytes(original, equals: [0, 1, 2, 3])
        ByteBufferTest.expectBytes(copy, equals: [0, 1, 2, 0xFF])

    }


    @Test
    func `OutputSpan initializer writes the initialized prefix`() {

        let expected = ByteBufferTest.sequentialBytes(count: 96)

        let buffer = ByteBuffer(capacity: 128) { output in
            for byte in expected {
                output.append(byte)
            }
        }

        #expect(buffer.count == expected.count)
        #expect(buffer.capacity == 128)
        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `OutputSpan append appends only initialized bytes`() {

        let prefix = [0xAA, 0xBB] as [UInt8]
        let suffix = ByteBufferTest.sequentialBytes(count: 40, startingAt: 0x20)
        var buffer = ByteBuffer(prefix)

        buffer.append(additionalCapacity: 64) { output in
            for byte in suffix {
                output.append(byte)
            }
        }

        ByteBufferTest.expectBytes(buffer, equals: prefix + suffix)

    }


    @Test
    func `OutputRawSpan initializer writes raw bytes`() {

        let value = 0xAABB_CCDD as UInt32
        let valueBytes = ByteBufferTest.bytes(of: value)

        let buffer = ByteBuffer(rawCapacity: 16) { output in
            output.append(0x11)
            output.append(value, as: UInt32.self)
        }

        ByteBufferTest.expectBytes(buffer, equals: [0x11] + valueBytes)

    }


    @Test
    func `OutputRawSpan append writes raw bytes`() {

        var buffer = ByteBuffer([0x11] as [UInt8])
        let value = 0xAABB_CCDD as UInt32
        let valueBytes = ByteBufferTest.bytes(of: value)

        buffer.append(additionalRawCapacity: 8) { output in
            output.append(0x22)
            output.append(value, as: UInt32.self)
        }

        ByteBufferTest.expectBytes(buffer, equals: [0x11, 0x22] + valueBytes)

    }


    @Test
    func `Negative OutputSpan initializer capacity traps`() async {

        await #expect(processExitsWith: .failure) {
            _ = ByteBuffer(capacity: -1) { _ in }
        }

    }


    @Test
    func `Negative OutputRawSpan initializer capacity traps`() async {

        await #expect(processExitsWith: .failure) {
            _ = ByteBuffer(rawCapacity: -1) { _ in }
        }

    }


    @Test
    func `Negative OutputSpan append capacity traps`() async {

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer()
            buffer.append(additionalCapacity: -1) { _ in }
        }

    }


    @Test
    func `Negative OutputRawSpan append capacity traps`() async {

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer()
            buffer.append(additionalRawCapacity: -1) { _ in }
        }

    }


    @Test
    func `Replacing unsafe scoped mutable pointer storage traps`() async {

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer([0, 1, 2] as [UInt8])
            let replacement = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 3)
            defer { replacement.deallocate() }

            buffer.withUnsafeMutableBufferPointer { pointer in
                pointer = replacement
            }
        }

    }


    @Test
    func `Replacing output span storage traps`() async {

        await #expect(processExitsWith: .failure) {
            let replacement = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 4)
            defer { replacement.deallocate() }

            _ = ByteBuffer(capacity: 4) { output in
                output = .init(buffer: replacement, initializedCount: replacement.count)
            }
        }

    }

}
