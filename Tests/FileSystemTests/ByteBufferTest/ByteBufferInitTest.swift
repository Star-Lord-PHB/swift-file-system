import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    @Test("Initialization with count")
    func initializationWithCount() async throws {

        let buffer = ByteBuffer(count: 100)
        let data = Data(count: 100)

        expectEqual(buffer, data)

    }


    @Test("Initialization with capacity")
    func initializationWithCapacity() async throws {
        
        let buffer = ByteBuffer(capacity: 100)

        #expect(buffer.capacity == 100)
        #expect(buffer.count == 0)
        #expect(buffer.storage.buffer.count == 100)
        #expect(buffer.storage.buffer.baseAddress != nil)

    }


    @Test("Initialization with repeated values")
    func initializationWithRepeatedValues() async throws {
        
        let buffer = ByteBuffer(repeating: 0xAB, count: 100)
        let data = Data(repeating: 0xAB, count: 100)

        expectEqual(buffer, data)

    }


    @Test("Initialization with data")
    func initializationWithData() async throws {
        
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let buffer = ByteBuffer(data)

        expectEqual(buffer, data)

    }


    @Test("Initialization with Sequence")
    func initializationWithSequence() async throws {
        
        let sequence = sequence(first: 0 as UInt8, next: { $0 == UInt8.max ? nil : $0 + 1 })

        let buffer = ByteBuffer(sequence)
        let data = Data(sequence)

        expectEqual(buffer, data)

    }


    @Test("Initialization with ByteBuffer")
    func initializationWithByteBuffer() async throws {
        
        var data = Data([UInt8](repeating: 0xCD, count: 50))
        let sourceBuffer = ByteBuffer(data)
        var buffer = ByteBuffer(sourceBuffer)

        #expect(sourceBuffer.storage === buffer.storage)
        #expect(sourceBuffer.count == buffer.count)
        #expect(sourceBuffer.startOffsetInStorage == buffer.startOffsetInStorage)

        buffer[0] = 0xAB
        data[0] = 0xAB

        #expect(sourceBuffer.storage !== buffer.storage)
        expectEqual(buffer, data)

    }


    @Test("Initialization with Slice of ByteBuffer")
    func initializationWithSliceOfByteBuffer() async throws {

        var data = Data([UInt8](repeating: 0xCD, count: 50))
        let sliceRange = 10..<25
        let sourceBuffer = ByteBuffer(data)
        let slice = sourceBuffer[sliceRange]
        var buffer = ByteBuffer(slice)

        #expect(sourceBuffer.storage === buffer.storage)
        #expect(slice.count == buffer.count)
        #expect(sourceBuffer.startOffsetInStorage + slice.startIndex == buffer.startOffsetInStorage)

        buffer[0] = 0xAB
        data[10] = 0xAB

        #expect(sourceBuffer.storage !== buffer.storage)
        expectEqual(buffer, data[sliceRange])

    }

}