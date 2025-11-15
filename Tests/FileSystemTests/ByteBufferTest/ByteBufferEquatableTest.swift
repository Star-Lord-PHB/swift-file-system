import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    @Test("Equatable")
    func equatable() async throws {
        
        do {

            #expect(ByteBuffer() == ByteBuffer())

            #expect(ByteBuffer() == ByteBuffer([UInt8]()))

            #expect(ByteBuffer() == ByteBuffer(ByteBuffer([UInt8](repeating: 1, count: 128)).prefix(0)))
            
            #expect(ByteBuffer([UInt8](repeating: 1, count: 128)) == ByteBuffer(ByteBuffer([UInt8](repeating: 1, count: 256))[64 ..< 192]))

        }

        
        do {

            #expect(ByteBuffer() != ByteBuffer([1] as [UInt8]))

            #expect(ByteBuffer() != ByteBuffer(ByteBuffer([UInt8](repeating: 1, count: 128)).prefix(1)))

            #expect(ByteBuffer([1,2,3,4,5,6,7,8]) != ByteBuffer([1,2,3,4,5,6,7,8,9]))

            #expect(ByteBuffer([1,2,3,4,5,6,7,8]) != ByteBuffer(ByteBuffer([1,2,3,4,5,6,7,8])[1 ..< 7]))

            let buffer1 = ByteBuffer([1,2,3,4,5,6,7,8])
            let buffer2 = ByteBuffer(buffer1[0 ..< 7])
            #expect(buffer1 != buffer2)

        }

    }

}