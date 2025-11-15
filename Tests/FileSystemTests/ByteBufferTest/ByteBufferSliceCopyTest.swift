import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    @Test("Slice Copy")
    func sliceCopy() async throws {
        
        let data = Data((0 ..< 1_000_000).map { UInt8(truncatingIfNeeded: $0) })
        let byteBuffer = ByteBuffer(data)

        var dataSlice = Data(data[100_000 ..< 900_000])
        var sliceCopy = ByteBuffer(byteBuffer[100_000 ..< 900_000])

        // without modification, the slice copy should share storage with the original byte buffer
        #expect(sliceCopy.storage === byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 100_000)
        #expect(sliceCopy.count == 800_000)

        // modification, trigger CoW
        sliceCopy[0] = 0xFF
        dataSlice[0] = 0xFF

        // after modification, the slice copy should have its own storage
        // in addition, the memory layout should also be rebased to start from offset 0
        #expect(sliceCopy.storage !== byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 0)
        expectEqual(sliceCopy, dataSlice)

    }


    @Test("Slice Copy Append")
    func sliceCopyAppend() async throws {
        
        let data = Data((0 ..< 1_000_000).map { UInt8(truncatingIfNeeded: $0) })
        let byteBuffer = ByteBuffer(data)

        var dataSlice = Data(data[100_000 ..< 900_000])
        var sliceCopy = ByteBuffer(byteBuffer[100_000 ..< 900_000])

        // without modification, the slice copy should share storage with the original byte buffer
        #expect(sliceCopy.storage === byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 100_000)
        #expect(sliceCopy.count == 800_000)

        sliceCopy.append(contentsOf: [UInt8](repeating: 0xAA, count: 1000))
        dataSlice.append(contentsOf: [UInt8](repeating: 0xAA, count: 1000))

        expectEqual(sliceCopy, dataSlice)

        // after modification, the slice copy should have its own storage
        // in addition, the memory layout should also be rebased to start from offset 0
        #expect(sliceCopy.storage !== byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 0)

    }


    @Test("Slice Copy Replace SubRange (Increase Size)")
    func sliceCopyReplaceSubRangeIncreaseSize() async throws {
        
        let data = Data((0 ..< 1_000_000).map { UInt8(truncatingIfNeeded: $0) })
        let byteBuffer = ByteBuffer(data)

        var dataSlice = Data(data[100_000 ..< 900_000])
        var sliceCopy = ByteBuffer(byteBuffer[100_000 ..< 900_000])

        // without modification, the slice copy should share storage with the original byte buffer
        #expect(sliceCopy.storage === byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 100_000)
        #expect(sliceCopy.count == 800_000)

        sliceCopy.replaceSubrange(1_000 ..< 10_000, with: [UInt8](repeating: 0xBB, count: 20_000))
        dataSlice.replaceSubrange(1_000 ..< 10_000, with: [UInt8](repeating: 0xBB, count: 20_000))

        expectEqual(sliceCopy, dataSlice)

        // after modification, the slice copy should have its own storage
        // in addition, the memory layout should also be rebased to start from offset 0
        #expect(sliceCopy.storage !== byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 0)

    }


    @Test("Slice Copy Replace SubRange (Decrease Size)")
    func sliceCopyReplaceSubRangeDecreaseSize() async throws {
        
        let data = Data((0 ..< 1_000_000).map { UInt8(truncatingIfNeeded: $0) })
        let byteBuffer = ByteBuffer(data)

        var dataSlice = Data(data[100_000 ..< 900_000])
        var sliceCopy = ByteBuffer(byteBuffer[100_000 ..< 900_000])

        // without modification, the slice copy should share storage with the original byte buffer
        #expect(sliceCopy.storage === byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 100_000)
        #expect(sliceCopy.count == 800_000)

        sliceCopy.replaceSubrange(1_000 ..< 10_000, with: [UInt8](repeating: 0xCC, count: 1_000))
        dataSlice.replaceSubrange(1_000 ..< 10_000, with: [UInt8](repeating: 0xCC, count: 1_000))

        expectEqual(sliceCopy, dataSlice)

        // after modification, the slice copy should have its own storage
        // in addition, the memory layout should also be rebased to start from offset 0
        #expect(sliceCopy.storage !== byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 0)

    }


    @Test("Slice Copy Remove")
    func sliceCopyRemove() async throws {
        
        let data = Data((0 ..< 1_000_000).map { UInt8(truncatingIfNeeded: $0) })
        let byteBuffer = ByteBuffer(data)

        var dataSlice = Data(data[100_000 ..< 900_000])
        var sliceCopy = ByteBuffer(byteBuffer[100_000 ..< 900_000])

        // without modification, the slice copy should share storage with the original byte buffer
        #expect(sliceCopy.storage === byteBuffer.storage)
        #expect(sliceCopy.startOffsetInStorage == 100_000)
        #expect(sliceCopy.count == 800_000)

        sliceCopy.removeSubrange(500_000 ..< 600_000)
        dataSlice.removeSubrange(500_000 ..< 600_000)

        expectEqual(sliceCopy, dataSlice)

    }

}