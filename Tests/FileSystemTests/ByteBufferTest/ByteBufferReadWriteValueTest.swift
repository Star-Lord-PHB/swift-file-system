import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    struct MyTrivialType: Equatable {

        var a: Int32 = 1
        var b: Bool = true
        var c: Float = 0.0
        var f: Nested = .init()

        struct Nested: Equatable {
            var d: UInt8 = 255
            var e: Double = 3.14
        }

    }

    struct MyNonTrivialType: Equatable {
        var a: Int = 10
        var b: String = "ByteBuffer"
    }


    @Test("Read Write Value")
    func readWriteValue() async throws {
        
        var byteBuffer = ByteBuffer()

        byteBuffer.append(contentsOf: [UInt8](repeating: 1, count: 16)) // offset 0
        byteBuffer.append(rawBytesOf: 100 as Int)                       // offset 16
        byteBuffer.append(rawBytesOf: 0xFF as UInt8)                    // offset 24 (or 20 on 32-bit)
        byteBuffer.append(rawBytesOf: 3.14 as Double)                   // offset 25 (or 21 on 32-bit)
        byteBuffer.append(rawBytesOf: true)                             // offset 33 (or 29 on 32-bit)
        byteBuffer.append(contentsOf: "Hello ByteBuffer!".utf8)         // offset 34 (or 30 on 32-bit)
        byteBuffer.append(rawBytesOf: MyTrivialType())                  // offset 51 (or 47 on 32-bit)

        byteBuffer.append(rawBytesOf: 9.8 as Float)                     // offset 83 (or 79 on 32-bit)
        byteBuffer.store(rawBytesOf: 9 as Float, toOffset: byteBuffer.count - MemoryLayout<Float>.size)

        // direct load from offset 
        #expect(byteBuffer.load(fromOffset: Int.bitWidth == 64 ? 33 : 29, as: Bool.self) == true)

        // load via reader

        var reader = byteBuffer.reader()

        #expect(reader.readBytes(upTo: 4) == ByteBuffer([UInt8](repeating: 1, count: 4)))
        #expect(reader.readBytes(upTo: 12) == ByteBuffer([UInt8](repeating: 1, count: 12)))
        #expect(reader.readInt() == 100)
        #expect(reader.readUInt8() == 0xFF)
        #expect(reader.readDouble() == 3.14)
        #expect(reader.readBool() == true)
        #expect(reader.readString(upTo: 17) == "Hello ByteBuffer!")
        #expect(reader.read(as: MyTrivialType.self) == MyTrivialType())
        #expect(reader.readFloat() == 9 as Float)

    }


    #if swift(>=6.2)
    @Test("Read / Write Non-Trival Value (Error)")
    func readWriteNonTrivialValue() async throws {
        
        await #expect(processExitsWith: .failure) {
            var buffer = ByteBuffer()
            buffer.append(rawBytesOf: MyNonTrivialType())   // fatal error due to storing non-trivial type
        }

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer(count: MemoryLayout<MyNonTrivialType>.size)
            _ = buffer.load(fromOffset: 0, as: MyNonTrivialType.self)   // fatal error due to loading non-trivial type
        }

    }
    #endif

}