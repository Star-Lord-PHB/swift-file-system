import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class UnsafeSystemHandleTest: FileSystemTest {}

}



extension FileSystemTest.UnsafeSystemHandleTest {

    @Test("Open For Reading")
    func openForReading() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .readOnly())
            )

            do {
                var buffer = Data(count: 5)

                let bytesRead = try buffer.withUnsafeMutableBytes { bufferPtr in 
                    try handle.read(into: bufferPtr)
                }

                #expect(bytesRead == 5)
                #expect(try handle.tell() == 5)
                #expect(buffer == Data("Hello".utf8))
            }

            do {
                var buffer = Data(count: 100)

                let bytesRead = try buffer.withUnsafeMutableBytes { bufferPtr in 
                    try handle.read(into: bufferPtr)
                }

                #expect(bytesRead == 7)
                #expect(try handle.tell() == 12)
                #expect(buffer[..<bytesRead] == Data(" Swift!".utf8))
            }

            do {
                #expect(try handle.seek(to: -7, from: .end) == 5)
                #expect(try handle.tell() == 5)
            }

            #if !canImport(WinSDK)
            do {
                var buffer = Data(count: 5)
                let bytesRead = try buffer.withUnsafeMutableBytes { bufferPtr in 
                    try handle.pread(into: bufferPtr, from: 6)
                }
                #expect(bytesRead == 5)
                #expect(buffer == Data("Swift".utf8))
                #expect(try handle.tell() == 5)
            }
            #endif

            do {
                let buffer = Data(count: 10)
                #expect(throws: SystemError.self) {
                    try buffer.withUnsafeBytes { bufferPtr in
                        try handle.write(contentsOf: bufferPtr)
                    }
                }
            }

        }

    }


    @Test("Open For Writing (File Exists, No Truncate)")
    func openForWriting1() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .writeOnly)
            )

            do {
                let buffer = Data("Write".utf8)
                let bytesWritten = try buffer.withUnsafeBytes { bufferPtr in 
                    try handle.write(contentsOf: bufferPtr)
                }

                #expect(bytesWritten == 5)
                #expect(try handle.tell() == 5)
            }

            do {
                #expect(try handle.seek(to: -1, from: .current) == 4)
                #expect(try handle.tell() == 4)
            }

            do {
                let buffer = Data("ing in Swift".utf8)
                let bytesWritten = try buffer.withUnsafeBytes { bufferPtr in 
                    try handle.write(contentsOf: bufferPtr)
                }
                #expect(bytesWritten == 12)
                #expect(try handle.tell() == 16)
            }

            do {
                let newOffset = try handle.seek(to: 7)
                #expect(newOffset == 7)
                #expect(try handle.tell() == 7)
            }

            #if !canImport(WinSDK)
            do {
                let buffer = Data("Swift".utf8)
                let bytesWritten = try buffer.withUnsafeBytes { bufferPtr in
                    try handle.pwrite(contentsOf: bufferPtr, to: 8)
                }
                #expect(bytesWritten == 5)
                #expect(try handle.tell() == 7)
            }
            #endif 

            do {
                #if canImport(WinSDK)
                try handle.truncate(to: 16)
                #else
                try handle.truncate(to: 13)
                #endif
            }

        }

        do {
            let finalContents = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
            #if canImport(WinSDK)
            #expect(finalContents == "Writing in Swift")
            #else
            #expect(finalContents == "Writing Swift")
            #endif 
        }

    }


    @Test("Open for Writing (File Exists, Truncate)")
    func openForWriting2() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .writeOnly, truncate: true)
            )

            do {
                let buffer = Data("Serika".utf8)
                let bytesWritten = try buffer.withUnsafeBytes { bufferPtr in 
                    try handle.write(contentsOf: bufferPtr)
                }

                #expect(bytesWritten == 6)
                #expect(try handle.tell() == 6)
            }

        }

        do {
            let finalContents = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
            #expect(finalContents == "Serika")
        }

    }


    @Test("Open for Writing (File Exists, Append)")
    func openForWriting3() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Serika".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(access: .writeOnly, append: true)
            )

            do {
                let buffer = Data(" is Cute!".utf8)
                let bytesWritten = try buffer.withUnsafeBytes { bufferPtr in 
                    try handle.write(contentsOf: bufferPtr)
                }
                #expect(bytesWritten == 9)
                #expect(try handle.tell() == 15)
            }

        }

        do {
            let finalContents = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
            #expect(finalContents == "Serika is Cute!")
        }

    }


    @Test("Open for Writing (File Exist, Must Create)")
    func openForWriting4() async throws {
        
        let path = try makeFile(at: "test.txt")

        try await expectNoResHandleLeak {

            _ = #expect(throws: SystemError.self) {
                _ = try UnsafeSystemHandle.open(
                    at: path, 
                    openOptions: .init(
                        access: .writeOnly, 
                        creation: .assertMissing
                    )
                ) 
            }

        }

    }


    @Test("Open for Writing (File not Exist, Create)")
    func openForWriting5() async throws {
        
        let path = makePath(at: "test.txt")

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(
                    access: .writeOnly, 
                    creation: .createIfMissing
                )
            )

            do {
                let buffer = Data("Hello Swift!".utf8)
                let bytesWritten = try buffer.withUnsafeBytes { bufferPtr in 
                    try handle.write(contentsOf: bufferPtr)
                }
                #expect(bytesWritten == 12)
                #expect(try handle.tell() == 12)
            }

        }

        do {
            let finalContents = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
            #expect(finalContents == "Hello Swift!")
        }

    }


    @Test("Open for Writing (File Exist, Create)")
    func openForWriting() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Swift  is Cute!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(
                    access: .writeOnly, 
                    creation: .createIfMissing
                )
            )

            do {
                let buffer = Data("Serika".utf8)
                let bytesWritten = try buffer.withUnsafeBytes { bufferPtr in 
                    try handle.write(contentsOf: bufferPtr)
                }
                #expect(bytesWritten == 6)
                #expect(try handle.tell() == 6)
            }

        }

        do {
            let finalContents = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
            #expect(finalContents == "Serika is Cute!")
        }

    }

}