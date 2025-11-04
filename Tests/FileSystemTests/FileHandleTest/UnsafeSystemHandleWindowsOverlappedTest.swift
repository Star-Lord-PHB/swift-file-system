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
                    var overlapped = UnsafeSystemHandle.WindowsOverlapped(offset: 6)
                    try handle.read(into: bufferPtr, overlapped: &overlapped)
                    let result = try handle.waitForOverlappedResult(overlapped)
                    return result
                }

                #expect(bytesRead == 5)
                #expect(try handle.tell() == 0)
                #expect(buffer == Data("Swift".utf8))
            }

            do {
                var buffer1 = Data(count: 5)
                var buffer2 = Data(count: 5)

                var overlapped1 = UnsafeSystemHandle.WindowsOverlapped()
                var overlapped2 = UnsafeSystemHandle.WindowsOverlapped(offset: 2)

                try buffer1.withUnsafeMutableBytes { bufferPtr in 
                    try handle.read(into: bufferPtr, overlapped: &overlapped1)
                }

                try buffer2.withUnsafeMutableBytes { bufferPtr in 
                    try handle.read(into: bufferPtr, length: 3, overlapped: &overlapped2)
                }

                let bytesRead1 = try handle.waitForOverlappedResult(overlapped1)
                let bytesRead2 = try handle.waitForOverlappedResult(overlapped2)

                #expect(bytesRead1 == 5)
                #expect(bytesRead2 == 3)
                #expect(try handle.tell() == 0)
                #expect(buffer1 == Data("Hello".utf8))
                #expect(buffer2[..<3] == Data("llo".utf8))
                #expect(buffer2[3...] == Data([0, 0]))
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


    @Test("Open for Writing")
    func openForWriting() async throws {
        
        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly, noBlocking: true))

            do {
                let dataToWrite = Data("Serika!".utf8)

                let bytesWritten = try dataToWrite.withUnsafeBytes { bufferPtr in 
                    var overlapped = UnsafeSystemHandle.WindowsOverlapped(offset: 6)
                    try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(overlapped)
                }

                #expect(bytesWritten == 7)
                #expect(try handle.tell() == 0)

                let finalContents = try Data(contentsOf: URL(fileURLWithPath: path.string))
                #expect(finalContents == Data("Hello Serika!".utf8))
            }

            do {
                let dataToWrite1 = Data("Serika".utf8)
                let dataToWrite2 = Data("Hoshino".utf8)

                let bytesWritten1 = try dataToWrite1.withUnsafeBytes { bufferPtr in 
                    var overlapped = UnsafeSystemHandle.WindowsOverlapped()
                    try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(overlapped)
                }

                #expect(bytesWritten1 == 6)
                #expect(try handle.tell() == 0)
                #expect(try Data(contentsOf: URL(fileURLWithPath: path.string)) == Data("SerikaSerika!".utf8))

                let bytesWritten2 = try dataToWrite2.withUnsafeBytes { bufferPtr in 
                    var overlapped = UnsafeSystemHandle.WindowsOverlapped()
                    try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(overlapped)
                }

                #expect(bytesWritten2 == 7)
                #expect(try handle.tell() == 0)
                #expect(try Data(contentsOf: URL(fileURLWithPath: path.string)) == Data("Hoshinoerika!".utf8))
            }

            do {
                let dataToWrite = Data(" is cute".utf8)

                let bytesWritten = try dataToWrite.withUnsafeBytes { bufferPtr in 
                    try handle.withWindowsOverlapped { overlapped in
                        overlapped.offset = 7
                        return try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    }
                }

                #expect(bytesWritten == 8)
                #expect(try handle.tell() == 0)

                let finalContents = try Data(contentsOf: URL(fileURLWithPath: path.string))
                #expect(finalContents == Data("Hoshino is cute".utf8))
            }
            
        }

    }

}

#endif