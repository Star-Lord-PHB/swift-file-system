import Testing
import SwiftFileSystem



extension FileHandleAPITests.ReadTests {

    @Test
    func `Seek supports beginning current and end origins`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)

        #expect(try handle.currentOffset == 0)
        #expect(try handle.seek(to: 4) == 4)
        #expect(try handle.currentOffset == 4)
        #expect(try handle.seek(to: 2, relativeTo: .current) == 6)
        #expect(try handle.currentOffset == 6)
        #expect(try handle.seek(to: -3, relativeTo: .end) == 7)
        #expect(try handle.currentOffset == 7)
        #expect(try handle.read(length: 3) == ByteBuffer("789".utf8))
        #expect(try handle.currentOffset == 10)

        try handle.close()

    }


    @Test
    func `Seek permits positions past EOF`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)

        #expect(try handle.seek(to: 3, relativeTo: .end) == 13)
        #expect(try handle.read(length: 2).isEmpty)
        #expect(try handle.currentOffset == 13)

        try handle.close()

    }


    @Test
    func `Seek rejects positions before file start`() throws {

        let path = try workspace.makeFile(at: "file", contents: "0123456789")
        let handle = try ReadFileHandle(forFileAt: path)
        _ = try handle.seek(to: 2)

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
        let handle = try ReadFileHandle(forFileAt: path)
        try handle.seek(to: 1)

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
