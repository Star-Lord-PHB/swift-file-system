import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    @Test("Cow Append")
    func cowAppend() async throws {
        
        let buffer1 = ByteBuffer(Data(0 ..< 100))
        var buffer2 = buffer1

        #expect(buffer1.storage === buffer2.storage)

        buffer2.append(0xFF)

        #expect(buffer1.storage !== buffer2.storage)

        #expect(buffer1.count == 100)
        #expect(buffer2.count == 101)

        for i in 0 ..< 100 {
            #expect(buffer1[i] == UInt8(i))
            #expect(buffer2[i] == UInt8(i))
        }
        #expect(buffer2[100] == 0xFF)   

    }


    @Test("Cow Write Byte")
    func cowWriteByte() async throws {

        let buffer1 = ByteBuffer(Data(0 ..< 100))
        var buffer2 = buffer1

        #expect(buffer1.storage === buffer2.storage)

        buffer2[50] = 0xFF

        #expect(buffer1.storage !== buffer2.storage)

        #expect(buffer1.count == 100)
        #expect(buffer2.count == 100)

        for i in 0 ..< 100 {
            #expect(buffer1[i] == UInt8(i))
            #expect(buffer2[i] == (i == 50 ? 0xFF : UInt8(i)))
        }

    }

}