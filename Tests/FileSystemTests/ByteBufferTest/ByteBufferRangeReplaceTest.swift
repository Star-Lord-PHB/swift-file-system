import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    @Test("Insert Single Byte")
    func insertSingleByte() async throws {
        
        var data = Data(0 ..< 128)
        var buffer = ByteBuffer(data)

        for _ in 0 ..< 10 {
            buffer.insert(0xFF, at: 2)
            data.insert(0xFF, at: 2)
        }

        expectEqual(buffer, data)

        buffer.insert(0xEE, at: 0)
        data.insert(0xEE, at: 0)

        expectEqual(buffer, data)

        buffer.insert(0xDD, at: buffer.count)
        data.insert(0xDD, at: data.count)

        expectEqual(buffer, data)

    }


    @Test("Insert Array of Bytes")
    func insertArrayOfBytes() async throws {

        var data = Data(0 ..< 128)
        var buffer = ByteBuffer(data)

        let bytesToInsert = [0xFF, 0xEE, 0xDD] as [UInt8]

        buffer.insert(contentsOf: bytesToInsert, at: 10)
        data.insert(contentsOf: bytesToInsert, at: 10)

        expectEqual(buffer, data)

        buffer.insert(contentsOf: bytesToInsert, at: 0)
        data.insert(contentsOf: bytesToInsert, at: 0)

        expectEqual(buffer, data)

        buffer.insert(contentsOf: bytesToInsert, at: buffer.count)
        data.insert(contentsOf: bytesToInsert, at: data.count)

        expectEqual(buffer, data)

    }


    @Test("Insert RandomAccessCollection of Bytes")
    func insertRandomAccessCollectionOfBytes() async throws {

        var data = Data(0 ..< 128)
        var buffer = ByteBuffer(data)

        let collectionToInsert = (0xAA ... 0xAC) as ClosedRange<UInt8>

        buffer.insert(contentsOf: collectionToInsert, at: 10)
        data.insert(contentsOf: collectionToInsert, at: 10)

        expectEqual(buffer, data)

        buffer.insert(contentsOf: collectionToInsert, at: 0)
        data.insert(contentsOf: collectionToInsert, at: 0)

        expectEqual(buffer, data)

        buffer.insert(contentsOf: collectionToInsert, at: buffer.count)
        data.insert(contentsOf: collectionToInsert, at: data.count)

        expectEqual(buffer, data)

    }


    @Test("Replace Range of Bytes")
    func replaceRangeOfBytes() async throws {
        
        var data = Data(0 ..< 128)
        var buffer = ByteBuffer(data)

        do {

            let bytesToInsert = [0xFF, 0xEE, 0xDD] as [UInt8]

            buffer.replaceSubrange(10..<20, with: bytesToInsert)
            data.replaceSubrange(10..<20, with: bytesToInsert)

            expectEqual(buffer, data)

        }

        do {

            let bytesToInsert = (0 ..< 128) as Range<UInt8>

            buffer.replaceSubrange(20 ... 30, with: bytesToInsert)
            data.replaceSubrange(20 ... 30, with: bytesToInsert)

            expectEqual(buffer, data)

        }

        do {

            let bytesToInsert = [0xFF, 0xEE, 0xDD] as [UInt8]

            buffer.replaceSubrange((buffer.count - 5) ..< buffer.count, with: bytesToInsert)
            data.replaceSubrange((data.count - 5) ..< data.count, with: bytesToInsert)

            expectEqual(buffer, data)
            
        }

    }

}