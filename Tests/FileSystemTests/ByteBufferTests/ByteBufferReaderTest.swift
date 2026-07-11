import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



extension ByteBufferTest {

    @Suite("Reader")
    final class Reader {}

}



extension ByteBufferTest.Reader {

    @Test
    func `Reader exposes initial offsets and remaining byte count`() {

        let buffer = ByteBuffer([1, 2, 3] as [UInt8])
        let reader = buffer.reader()

        #expect(reader.count == 3)
        #expect(reader.readOffset == 0)
        #expect(reader.remainingBytes == 3)

    }


    @Test
    func `readByte consumes bytes until the end`() {

        var reader = ByteBuffer([1, 2, 3] as [UInt8]).reader()

        #expect(reader.readByte() == 1)
        #expect(reader.readOffset == 1)
        #expect(reader.readByte() == 2)
        #expect(reader.readByte() == 3)
        #expect(reader.readByte() == nil)
        #expect(reader.readOffset == 3)
        #expect(reader.remainingBytes == 0)

    }


    @Test
    func `readBytes(upTo:) handles zero, negative, partial, and oversized reads`() {

        var reader = ByteBuffer([1, 2, 3, 4, 5] as [UInt8]).reader()

        ByteBufferTest.expectBytes(reader.readBytes(upTo: 0), equals: [])
        ByteBufferTest.expectBytes(reader.readBytes(upTo: -1), equals: [])
        #expect(reader.readOffset == 0)

        ByteBufferTest.expectBytes(reader.readBytes(upTo: 2), equals: [1, 2])
        #expect(reader.readOffset == 2)

        ByteBufferTest.expectBytes(reader.readBytes(upTo: 99), equals: [3, 4, 5])
        #expect(reader.readOffset == 5)

        ByteBufferTest.expectBytes(reader.readBytes(upTo: 1), equals: [])
        #expect(reader.readOffset == 5)

    }


    @Test
    func `readBytes(upTo:operation:) passes contiguous bytes and advances`() {

        var reader = ByteBuffer([0x10, 0x11, 0x12, 0x13] as [UInt8]).reader()

        let bytes = reader.readBytes(upTo: 3) { rawBytes in
            Array(rawBytes)
        }

        #expect(bytes == [0x10, 0x11, 0x12] as [UInt8])
        #expect(reader.readOffset == 3)

        let empty = reader.readBytes(upTo: 0) { rawBytes in
            Array(rawBytes)
        }

        #expect(empty == [] as [UInt8])
        #expect(reader.readOffset == 3)

    }


    @Test
    func `readSpan(upTo:) returns borrowed raw bytes and advances`() {

        var reader = ByteBuffer([1, 2, 3, 4] as [UInt8]).reader()

        let span = reader.readSpan(upTo: 3)
        span.withUnsafeBytes { bytes in
            ByteBufferTest.expectBytes(bytes, equals: [1, 2, 3])
        }

        #expect(reader.readOffset == 3)
        #expect(reader.remainingBytes == 1)

    }


    @Test
    func `Typed reader helpers read values and stop at incomplete values`() {

        var buffer = ByteBuffer()
        buffer.append(rawBytesOf: -1 as Int)
        buffer.append(rawBytesOf: 2 as UInt)
        buffer.append(rawBytesOf: -3 as Int8)
        buffer.append(rawBytesOf: 4 as UInt8)
        buffer.append(rawBytesOf: -5 as Int16)
        buffer.append(rawBytesOf: 6 as UInt16)
        buffer.append(rawBytesOf: -7 as Int32)
        buffer.append(rawBytesOf: 8 as UInt32)
        buffer.append(rawBytesOf: -9 as Int64)
        buffer.append(rawBytesOf: 10 as UInt64)
        buffer.append(rawBytesOf: 1.25 as Float)
        buffer.append(rawBytesOf: 2.5 as Double)
        buffer.append(rawBytesOf: Float16(3.5))
        buffer.append(rawBytesOf: true)
        buffer.append(0xFF)

        var reader = buffer.reader()

        #expect(reader.readInt() == -1)
        #expect(reader.readUInt() == 2)
        #expect(reader.readInt8() == -3)
        #expect(reader.readUInt8() == 4)
        #expect(reader.readInt16() == -5)
        #expect(reader.readUInt16() == 6)
        #expect(reader.readInt32() == -7)
        #expect(reader.readUInt32() == 8)
        #expect(reader.readInt64() == -9)
        #expect(reader.readUInt64() == 10)
        #expect(reader.readFloat() == 1.25)
        #expect(reader.readDouble() == 2.5)
        #expect(reader.readFloat16() == Float16(3.5))
        #expect(reader.readBool() == true)

        let offsetBeforeIncompleteRead = reader.readOffset
        #expect(reader.readUInt16() == nil)
        #expect(reader.readOffset == offsetBeforeIncompleteRead)
        #expect(reader.readUInt8() == 0xFF)
        #expect(reader.readUInt8() == nil)

    }


    @Test
    func `Generic read(as:) reads custom trivial values`() {

        let value = ByteBufferTest.TrivialRecord()
        var buffer = ByteBuffer()
        buffer.append(rawBytesOf: value)

        var reader = buffer.reader()

        #expect(reader.read(as: ByteBufferTest.TrivialRecord.self) == value)
        #expect(reader.read(as: ByteBufferTest.TrivialRecord.self) == nil)

    }


    @Test
    func `readString(upToCodeUnits:encoding:) decodes UTF-8 bytes`() {

        let utf8String = "Hello ByteBuffer"
        var reader = ByteBuffer(utf8String.utf8).reader()

        #expect(reader.readString(upToCodeUnits: 5, encoding: UTF8.self) == "Hello")
        #expect(reader.readString(upToCodeUnits: 1, encoding: UTF8.self) == " ")
        #expect(reader.readString(upToCodeUnits: 100, encoding: UTF8.self) == "ByteBuffer")
        #expect(reader.readString(upToCodeUnits: 1, encoding: UTF8.self) == "")

        var zeroLengthReader = ByteBuffer("abc".utf8).reader()
        #expect(zeroLengthReader.readString(upToCodeUnits: 0, encoding: UTF8.self) == nil)
        #expect(zeroLengthReader.readOffset == 0)

    }


    @Test
    func `readString(upToCodeUnits:encoding:) decodes UTF-16 code units`() {

        let utf16String = "Hi \u{4E16}\u{754C}"
        let buffer = Array(utf16String.utf16).withUnsafeBytes { ByteBuffer($0) }
        var reader = buffer.reader()

        #expect(reader.readString(upToCodeUnits: 3, encoding: UTF16.self) == "Hi ")
        #expect(reader.readString(upToCodeUnits: 100, encoding: UTF16.self) == "\u{4E16}\u{754C}")
        #expect(reader.remainingBytes == 0)

    }


    @Test
    func `skip advances by at most the remaining byte count`() {

        var reader = ByteBuffer([1, 2, 3, 4] as [UInt8]).reader()

        reader.skip(2)
        #expect(reader.readOffset == 2)
        #expect(reader.readByte() == 3)

        reader.skip(99)
        #expect(reader.readOffset == 4)
        #expect(reader.readByte() == nil)

    }


    @Test
    func `Reader on unique slice-backed buffers reads from the slice start`() {

        var reader = ByteBufferTest.makeUniqueSliceBackedBuffer(sliceRange: 8 ..< 12).reader()

        #expect(reader.readOffset == 0)
        #expect(reader.remainingBytes == 4)
        #expect(reader.readByte() == 8)
        ByteBufferTest.expectBytes(reader.readBytes(upTo: 3), equals: [9, 10, 11])

    }


    @Test
    func `Negative skip traps`() async {

        await #expect(processExitsWith: .failure) {
            var reader = ByteBuffer([1, 2, 3] as [UInt8]).reader()
            reader.skip(-1)
        }

    }

}
