import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Raw Byte Access")
    final class RawByteAccess {}

}



extension ByteBufferTest.RawByteAccess {

    struct NonTrivialRecord: Equatable {
        var name = "ByteBuffer"
    }


    @Test
    func `append(rawBytesOf:) and load(fromOffset:as:) preserve typed values`() {

        var buffer = ByteBuffer()

        let byteOffset = buffer.count
        buffer.append(rawBytesOf: 0xAB as UInt8)

        let unalignedUInt32Offset = buffer.count
        buffer.append(rawBytesOf: 0x1122_3344 as UInt32)

        let doubleOffset = buffer.count
        buffer.append(rawBytesOf: 3.25 as Double)

        let recordOffset = buffer.count
        buffer.append(rawBytesOf: ByteBufferTest.TrivialRecord())

        #expect(buffer.load(fromOffset: byteOffset, as: UInt8.self) == 0xAB)
        #expect(buffer.load(fromOffset: unalignedUInt32Offset, as: UInt32.self) == 0x1122_3344)
        #expect(buffer.load(fromOffset: doubleOffset, as: Double.self) == 3.25)
        #expect(buffer.load(fromOffset: recordOffset, as: ByteBufferTest.TrivialRecord.self) == ByteBufferTest.TrivialRecord())

    }


    @Test
    func `store(rawBytesOf:toOffset:) overwrites typed values`() {

        var buffer = ByteBuffer(count: 1 + MemoryLayout<UInt32>.size + MemoryLayout<ByteBufferTest.TrivialRecord>.size)
        buffer[0] = 0xFE

        let integerOffset = 1
        let recordOffset = integerOffset + MemoryLayout<UInt32>.size

        buffer.store(rawBytesOf: 0xAABB_CCDD as UInt32, toOffset: integerOffset)
        buffer.store(rawBytesOf: ByteBufferTest.TrivialRecord(count: 0xDEAD_BEEF, delta: 42, flag: false), toOffset: recordOffset)

        #expect(buffer[0] == 0xFE)
        #expect(buffer.load(fromOffset: integerOffset, as: UInt32.self) == 0xAABB_CCDD)
        #expect(
            buffer.load(fromOffset: recordOffset, as: ByteBufferTest.TrivialRecord.self) ==
            ByteBufferTest.TrivialRecord(count: 0xDEAD_BEEF, delta: 42, flag: false)
        )

    }


    @Test
    func `store(bytes:toOffset:) accepts contiguous and non-contiguous collections`() {

        var buffer = ByteBuffer(repeating: 0, count: 12)

        buffer.store(bytes: [1, 2, 3, 4] as [UInt8], toOffset: 2)
        buffer.store(bytes: ByteBufferTest.NonContiguousBytes([0xAA, 0xBB, 0xCC]), toOffset: 7)
        buffer.store(bytes: [] as [UInt8], toOffset: buffer.count)

        ByteBufferTest.expectBytes(
            buffer,
            equals: [0, 0, 1, 2, 3, 4, 0, 0xAA, 0xBB, 0xCC, 0, 0]
        )

    }


    @Test
    func `store(bytes:toOffset:) flushes large non-contiguous collections`() {

        let replacement = ByteBufferTest.sequentialBytes(count: 40, startingAt: 0x80)
        var buffer = ByteBuffer(repeating: 0, count: 48)
        var expected = Array(repeating: UInt8(0), count: 48)

        buffer.store(bytes: ByteBufferTest.NonContiguousBytes(replacement), toOffset: 4)
        expected.replaceSubrange(4 ..< 44, with: replacement)

        ByteBufferTest.expectBytes(buffer, equals: expected)

    }


    @Test
    func `Raw byte storage matches Swift's in-memory representation`() {

        let value = 0x0102_0304 as UInt32
        var buffer = ByteBuffer()

        buffer.append(rawBytesOf: value)

        ByteBufferTest.expectBytes(buffer, equals: ByteBufferTest.bytes(of: value))

    }


    @Test
    func `Invalid raw byte offsets trap`() async {

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer(count: 4)
            _ = buffer.load(fromOffset: -1, as: UInt8.self)
        }

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer(count: 4)
            _ = buffer.load(fromOffset: 1, as: UInt32.self)
        }

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer(count: 4)
            buffer.store(rawBytesOf: 0xAABB_CCDD as UInt32, toOffset: 1)
        }

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer(count: 4)
            buffer.store(bytes: [1, 2] as [UInt8], toOffset: 3)
        }

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer(count: 4)
            buffer.store(bytes: [] as [UInt8], toOffset: buffer.count + 1)
        }

    }


    @Test
    func `Non-trivial raw value access traps`() async {

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer()
            buffer.append(rawBytesOf: NonTrivialRecord())
        }

        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer(count: MemoryLayout<NonTrivialRecord>.size)
            buffer.store(rawBytesOf: NonTrivialRecord(), toOffset: 0)
        }

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer(count: MemoryLayout<NonTrivialRecord>.size)
            _ = buffer.load(fromOffset: 0, as: NonTrivialRecord.self)
        }

    }


    @Test
    func `Raw loads on unique slice-backed buffers use slice-relative offsets`() {

        let buffer = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 16)

        #expect(buffer.load(fromOffset: 0, as: UInt8.self) == 8)
        #expect(buffer.load(fromOffset: 1, as: UInt8.self) == 9)

    }


    @Test
    func `Raw byte stores on unique slice-backed buffers use slice-relative offsets`() {

        var bytesBuffer = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 12)

        bytesBuffer.store(bytes: [0xAA, 0xBB] as [UInt8], toOffset: 0)

        ByteBufferTest.expectBytes(bytesBuffer, equals: [0xAA, 0xBB, 10, 11])

    }


    @Test
    func `Raw value stores on unique slice-backed buffers use slice-relative offsets`() {

        var valueBuffer = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 12)

        valueBuffer.store(rawBytesOf: 0xCC as UInt8, toOffset: 0)

        ByteBufferTest.expectBytes(valueBuffer, equals: [0xCC, 9, 10, 11])

    }


    @Test
    func `Storing empty non-contiguous bytes into an empty buffer is a no-op`() async {

        await #expect(processExitsWith: .success) {
            var buffer = ByteBuffer()
            buffer.store(bytes: ByteBufferTest.NonContiguousBytes([]), toOffset: 0)
        }

    }

}
