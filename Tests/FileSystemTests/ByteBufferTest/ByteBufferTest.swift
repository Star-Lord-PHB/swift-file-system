import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    @Suite("Test ByteBuffer")
    final class ByteBufferTest {}

}



extension FileSystemTest.ByteBufferTest {

    func expectEqual(_ lhs: ByteBuffer, _ rhs: Data, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(byteBufferToData(lhs) == rhs, "ByteBuffer and Data are not equal", sourceLocation: sourceLocation)
    }


    func expectEqual(_ lhs: ByteBuffer.SubSequence, _ rhs: Data, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(byteBufferToData(lhs) == rhs, "ByteBuffer and Data are not equal", sourceLocation: sourceLocation)
    }


    func byteBufferToData(_ byteBuffer: ByteBuffer) -> Data {
        return Data(buffer: .init(
            start: byteBuffer.storage.buffer.baseAddress?.assumingMemoryBound(to: UInt8.self), 
            count: byteBuffer.count
        ))
    }
    

    func byteBufferToData(_ byteBuffer: ByteBuffer.SubSequence) -> Data {
        let slicedBuffer = UnsafeRawBufferPointer(rebasing: byteBuffer.base.storage.buffer[byteBuffer.startIndex..<byteBuffer.endIndex])
        return Data(buffer: slicedBuffer.assumingMemoryBound(to: UInt8.self))
    }

}