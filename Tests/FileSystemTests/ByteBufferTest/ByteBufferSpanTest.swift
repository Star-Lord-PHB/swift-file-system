import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    @Test("Span")
    func span() async throws {
        
        let data = Data(0 ..< 100)
        let buffer = ByteBuffer(data)

        let dataSpan = data.span 
        let bufferSpan = buffer.span

        #expect(dataSpan.count == bufferSpan.count)

        for i in 0 ..< dataSpan.count {
            #expect(dataSpan[i] == bufferSpan[i])
        }

    }


    @Test("Mutable Span")
    func mutableSpan() async throws {
        
        var data = Data(0 ..< 100)
        var buffer = ByteBuffer(data)

        var mutableDataSpan = data.mutableSpan
        var mutableBufferSpan = buffer.mutableSpan

        #expect(mutableDataSpan.count == mutableBufferSpan.count)

        for i in 0 ..< mutableDataSpan.count {
            #expect(mutableDataSpan[i] == mutableBufferSpan[i])
        }

        mutableDataSpan[50] = 0xFF
        mutableBufferSpan[50] = 0xEE

        #expect(data[50] == 0xFF)
        #expect(buffer[50] == 0xEE)

    }

}



extension FileSystemTest.ByteBufferTest {

    @Test("Output Span Init")
    func outputSpanInit() async throws {

        let content = sequence(first: 0 as UInt8, next: { $0 &+ 1 }).prefix(1_000_000)
        let data = Data(content)

        let buffer = ByteBuffer(capacity: 1_000_000) { outputSpan in
            for byte in content {
                outputSpan.append(byte)
            }
        }

        expectEqual(buffer, data)

    }


    @Test("Output Span Append")
    func outputSpanAppend() async throws {

        let content = Array((0 ..< 1_000_000).map { UInt8(truncatingIfNeeded: $0) })
        var data = Data(content)
        var buffer = ByteBuffer(data)

        data.append(contentsOf: content)

        buffer.append(additionalCapacity: content.count) { outputSpan in
            for byte in content {
                outputSpan.append(byte)
            }
        }

        expectEqual(buffer, data)

    }


    #if swift(>=6.2)
    @Test("Invalid Replace OutputSpan")
    func invalidReplaceOutputSpan() async throws {
        
        await #expect(processExitsWith: .failure) {
            let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 10)
            defer { buffer.deallocate() }
            _ = ByteBuffer(capacity: 10) { outputSpan in 
                outputSpan = .init(buffer: buffer, initializedCount: buffer.count)
            }
        }

    }
    #endif

}