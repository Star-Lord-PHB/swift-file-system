import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest.ByteBufferTest {

    @Test("Read byte")
    func readByte() async throws {

        let data = Data(0 ..< 100)
        let buffer = ByteBuffer(data)

        for i in 0..<data.count {
            #expect(buffer[i] == data[i])
        }

    }


    @Test("Read Slice")
    func readSlice() async throws {
        
        let data = Data(0 ..< 100)
        let buffer = ByteBuffer(data)

        do {
            let slice = buffer[10..<20]
            let expectedSlice = data[10..<20]
            expectEqual(slice, expectedSlice)
        }

        do {
            let slice = buffer[70..<100]
            let expectedSlice = data[70..<100]
            expectEqual(slice, expectedSlice)
        }

    }


    #if swift(>=6.2)
    @Test("Read Out of Range")
    func readOutOfRange() async throws {

        let result1 = await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer(Data(0 ..< 100))
            _ = buffer[100]
        }
        print(String(data: Data(result1?.standardErrorContent ?? []), encoding: .utf8) ?? "")

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer(Data(0 ..< 100))
            _ = buffer[90 ..< 110]
        }

        await #expect(processExitsWith: .failure) {
            let buffer = ByteBuffer(Data(0 ..< 100))
            _ = buffer[-10 ..< 10]
        }

    }
    #endif

}