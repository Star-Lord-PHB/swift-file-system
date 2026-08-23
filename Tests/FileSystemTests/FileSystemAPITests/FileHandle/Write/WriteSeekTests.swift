import Testing
import SwiftFileSystem



extension FileHandleAPITests.WriteTests {

    @Test
    func `Seek supports beginning current and end origins`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)

        #expect(try handle.currentOffset == 0)
        #expect(try handle.seek(to: 4, relativeTo: .beginning) == 4)
        #expect(try handle.seek(to: 2, relativeTo: .current) == 6)
        #expect(try handle.seek(to: -2, relativeTo: .end) == 8)
        #expect(try handle.write(ByteBuffer("XY".utf8)) == 2)
        #expect(try handle.currentOffset == 10)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer("01234567XY".utf8))

    }


    @Test
    func `Writing past EOF creates a zero-filled gap`() throws {

        let path = try workspace.makeFile(at: "file", contents: "abc")
        let handle = try WriteFileHandle(forFileAt: path)

        #expect(try handle.seek(to: 2, relativeTo: .end) == 5)
        #expect(try handle.write(ByteBuffer("z".utf8)) == 1)
        #expect(try handle.currentOffset == 6)

        try handle.close()

        #expect(try capturedContents(at: path) == ByteBuffer([0x61, 0x62, 0x63, 0, 0, 0x7A]))

    }


    @Test
    func `Seek rejects positions before file start`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        _ = try handle.seek(to: 2, relativeTo: .beginning)

        let beginningError = #expect(throws: PlatformError.self) {
            try handle.seek(to: -1, relativeTo: .beginning)
        }
        #expect(beginningError?.kind == .invalidInput)
        #expect(try handle.currentOffset == 2)

        let currentError = #expect(throws: PlatformError.self) {
            try handle.seek(to: -3, relativeTo: .current)
        }
        #expect(currentError?.kind == .invalidInput)
        #expect(try handle.currentOffset == 2)

        let endError = #expect(throws: PlatformError.self) {
            try handle.seek(to: -11, relativeTo: .end)
        }
        #expect(endError?.kind == .invalidInput)
        #expect(try handle.currentOffset == 2)

        try handle.close()

    }


    @Test
    func `Seek rejects arithmetic overflow`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try WriteFileHandle(forFileAt: path)
        _ = try handle.seek(to: 1, relativeTo: .beginning)

        let currentError = #expect(throws: PlatformError.self) {
            try handle.seek(to: Int64.max, relativeTo: .current)
        }

        #if canImport(WinSDK) || canImport(Darwin)
        #expect(currentError?.kind == .arithmeticOverflow)
        #endif
        #expect(try handle.currentOffset == 1)

        let endError = #expect(throws: PlatformError.self) {
            try handle.seek(to: Int64.max, relativeTo: .end)
        }

        #if canImport(WinSDK) || canImport(Darwin)
        #expect(endError?.kind == .arithmeticOverflow)
        #endif
        #expect(try handle.currentOffset == 1)

        try handle.close()

    }

}
