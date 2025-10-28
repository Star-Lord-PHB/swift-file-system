#if canImport(WinSDK)

import Testing
import SystemPackage
import Foundation
@testable import FileSystem

import WinSDK



extension FileSystemTest {

    final class UnsafeSystemHandleWindowsOverlappedTest: FileSystemTest {}

}



extension FileSystemTest.UnsafeSystemHandleWindowsOverlappedTest {

    @Test("Open for Reading")
    func openForReading() async throws {

        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noBlocking: true))

            do {
                var buffer = Data(count: 5)

                let bytesRead = try buffer.withUnsafeMutableBytes { bufferPtr in 
                    try handle.pread(into: bufferPtr, from: 6)
                }

                #expect(bytesRead == 5)
                #expect(try handle.tell() == 0)
                #expect(buffer == Data("Swift".utf8))
            }

            do {
                var buffer = Data(count: 5)

                let bytesRead = try buffer.withUnsafeMutableBytes { bufferPtr in 
                    try handle.withWindowsOverlapped { overlapped in
                        overlapped.offset = 5
                        return try handle.read(into: bufferPtr, length: 3, overlapped: &overlapped)
                    }
                }

                #expect(bytesRead == 3)
                #expect(try handle.tell() == 0)
                #expect(buffer[..<3] == Data(" Sw".utf8))
                #expect(buffer[3...] == Data([0, 0]))
            }
            
        }

    }


    @Test("Open for Reading (Unsupported Read)")
    func openForReadingUnsupportedRead() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noBlocking: true))

            var buffer = Data(count: 5)

            let error = try #require(throws: SystemError.self) {
                try buffer.withUnsafeMutableBytes { bufferPtr in 
                    _ = try handle.read(into: bufferPtr)
                }
            }

            #expect(error.code == ERROR_INVALID_PARAMETER)
            
        }

    }


    @Test("Open for Writing")
    func openForWriting() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly, noBlocking: true))

            do {
                let dataToWrite = Data("Serika!".utf8)

                let bytesWritten = try dataToWrite.withUnsafeBytes { bufferPtr in 
                    try handle.pwrite(contentsOf: bufferPtr, to: 6)
                }

                #expect(bytesWritten == 7)
                #expect(try handle.tell() == 0)

                let finalContents = try Data(contentsOf: URL(fileURLWithPath: path.string))
                #expect(finalContents == Data("Hello Serika!".utf8))
            }

            do {
                let dataToWrite = Data(" cat".utf8)

                let bytesWritten = try dataToWrite.withUnsafeBytes { bufferPtr in 
                    try handle.withWindowsOverlapped { overlapped in
                        overlapped.offset = 12
                        return try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    }
                }

                #expect(bytesWritten == 4)
                #expect(try handle.tell() == 0)

                let finalContents = try Data(contentsOf: URL(fileURLWithPath: path.string))
                #expect(finalContents == Data("Hello Serika cat".utf8))
            }
            
        }

    }


    @Test("Open for Writing (Unsupported Write)")
    func openForWritingUnsupportedWrite() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly, noBlocking: true))

            let dataToWrite = Data("Serika!".utf8)

            let error = try #require(throws: SystemError.self) {
                try dataToWrite.withUnsafeBytes { bufferPtr in 
                    _ = try handle.write(contentsOf: bufferPtr)
                }
            }

            #expect(error.code == ERROR_INVALID_PARAMETER)
            
        }   

    }

}

#endif