import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    @Test("Append Single Byte")
    func append() async throws {
        
        var buffer = ByteBuffer()
        var data = Data()

        for i in 0 ..< 1000 {
            buffer.append(UInt8(i % Int(UInt8.max)))
            data.append(UInt8(i % Int(UInt8.max)))
        }

        expectEqual(buffer, data)

    }


    @Test("Append Array of Bytes")
    func appendArrayOfBytes() async throws {
        
        var buffer = ByteBuffer()
        var data = Data()

        let bytesToAppend = [UInt8](0 ..< 10)

        for _ in 0 ..< 100 {
            buffer.append(contentsOf: bytesToAppend)
            data.append(contentsOf: bytesToAppend)
        }

        expectEqual(buffer, data)

    }


    @Test("Append RandomAccessCollection of Bytes")
    func appendRandomAccessCollectionOfBytes() async throws {

        var buffer = ByteBuffer()
        var data = Data()

        let bytesToAppend = (0 ..< 10) as Range<UInt8>

        for _ in 0 ..< 100 {
            buffer.append(contentsOf: bytesToAppend)
            data.append(contentsOf: bytesToAppend)
        }

        expectEqual(buffer, data)

    }


    @Test("Append Sequence of Bytes")
    func appendSequenceOfBytes() async throws {
        
        let sequenceToAppend = sequence(first: 0 as UInt8, next: { $0 == UInt8.max ? nil : $0 + 1 })

        var buffer = ByteBuffer()
        var data = Data()

        for _ in 0 ..< 100 {
            buffer.append(contentsOf: sequenceToAppend)
            data.append(contentsOf: sequenceToAppend)
        }

        expectEqual(buffer, data)

    }

}