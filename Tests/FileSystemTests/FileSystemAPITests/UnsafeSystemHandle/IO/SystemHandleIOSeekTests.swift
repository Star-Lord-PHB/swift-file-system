import Testing
import Foundation
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.IOTests {

    @Test
    func `Seek positions from beginning, current and end`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        try #expect(handle.seek(to: 6) == 6)
        try #expect(handle.seek(to: 2, from: .current) == 8)
        try #expect(handle.seek(to: -2, from: .current) == 6)
        try #expect(handle.seek(to: 0, from: .end) == 12)
        try #expect(handle.seek(to: -6, from: .end) == 6)

        var buffer = Data(count: 6)
        _ = try handle.read(into: buffer.mutableBytes)

        #expect(buffer == Data("Swift!".utf8))

        try handle.close()

    }


    @Test
    func `Seek beyond EOF is allowed and reads zero bytes there`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        try #expect(handle.seek(to: 100) == 100)
        #expect(try handle.tell() == 100)

        var buffer = Data(count: 4)
        let bytesRead = try handle.read(into: buffer.mutableBytes)

        #expect(bytesRead == 0)

        try handle.close()

    }


    @Test
    func `Negative seek reports invalidInput and keeps the offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly()))

        try handle.seek(to: 3)

        let error = #expect(throws: LowLevelError.self) {
            try handle.seek(to: -1)
        }

        #expect(error?.kind == .invalidInput)
        #if canImport(WinSDK)
        #expect(error?.systemCode == .negativeSeek)
        #else
        #expect(error?.systemCode == .invalidArgument)
        #endif

        let endError = #expect(throws: LowLevelError.self) {
            try handle.seek(to: -20, from: .end)
        }

        #expect(endError?.kind == .invalidInput)
        #expect(try handle.tell() == 3)

        try handle.close()

    }

}
