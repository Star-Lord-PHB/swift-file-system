#if canImport(WinSDK)

import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore

import WinSDK



extension FileSystemTest {

    final class UnsafeSystemHandleWindowsOverlappedTest: FSIsolatedTestCase {}

}



extension FileSystemTest.UnsafeSystemHandleWindowsOverlappedTest {

    @Test("Open for Reading")
    func openForReading() async throws {

        let path = try self.makeFile(at: "test.txt", contents: .init("Hello Swift!".utf8))

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noBlocking: true))

            do {
                var buffer = Data(count: 5)

                #if swift(>=6.2)
                var overlapped = WindowsOverlapped(offset: 6)
                var span = buffer.mutableBytes
                let pendingOverlapped = try handle.read(into: &span, overlapped: &overlapped)
                let bytesRead = try handle.waitForOverlappedResult(pendingOverlapped)
                #else
                let bytesRead = try buffer.withUnsafeMutableBytes { bufferPtr in 
                    var overlapped = WindowsOverlapped(offset: 6)
                    let pendingOverlapped = try handle.read(into: bufferPtr, overlapped: &overlapped)
                    let result = try handle.waitForOverlappedResult(pendingOverlapped)
                    return result
                }
                #endif

                #expect(bytesRead == 5)
                #expect(try handle.tell() == 0)
                #expect(buffer == Data("Swift".utf8))
            }

            do {
                var buffer1 = Data(count: 5)
                var buffer2 = Data(count: 5)

                var overlapped1 = WindowsOverlapped()
                var overlapped2 = WindowsOverlapped(offset: 2)

                let (bytesRead1, bytesRead2) = try buffer1.withUnsafeMutableBytes { bufferPtr in 
                    let pendingOverlapped1 = try handle.read(into: bufferPtr, overlapped: &overlapped1)
                    let bytesRead2 = try buffer2.withUnsafeMutableBytes { bufferPtr in 
                        let pendingOverlapped2 = try handle.read(into: bufferPtr, length: 3, overlapped: &overlapped2)
                        return try handle.waitForOverlappedResult(pendingOverlapped2)
                    }
                    let bytesRead1 = try handle.waitForOverlappedResult(pendingOverlapped1)
                    return (bytesRead1, bytesRead2)
                }

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
                    var overlapped = WindowsOverlapped()
                    overlapped.offset = 5
                    let pendingOverlapped = try handle.read(into: bufferPtr, length: 3, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(pendingOverlapped)    
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

            let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly(), noBlocking: true))

            do {
                let dataToWrite = Data("Serika!".utf8)

                #if swift(>=6.2)
                var overlapped = WindowsOverlapped(offset: 6)
                let pendingOverlapped = try handle.write(contentsOf: dataToWrite.bytes, overlapped: &overlapped)
                let bytesWritten = try handle.waitForOverlappedResult(pendingOverlapped)
                #else
                let bytesWritten = try dataToWrite.withUnsafeBytes { bufferPtr in 
                    var overlapped = WindowsOverlapped(offset: 6)
                    let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(pendingOverlapped)
                }
                #endif

                #expect(bytesWritten == 7)
                #expect(try handle.tell() == 0)

                let finalContents = try Data(contentsOf: URL(fileURLWithPath: path.string))
                #expect(finalContents == Data("Hello Serika!".utf8))
            }

            do {
                let dataToWrite1 = Data("Serika".utf8)
                let dataToWrite2 = Data("Hoshino".utf8)

                let bytesWritten1 = try dataToWrite1.withUnsafeBytes { bufferPtr in 
                    var overlapped = WindowsOverlapped()
                    let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(pendingOverlapped)
                }

                #expect(bytesWritten1 == 6)
                #expect(try handle.tell() == 0)
                #expect(try Data(contentsOf: URL(fileURLWithPath: path.string)) == Data("SerikaSerika!".utf8))

                let bytesWritten2 = try dataToWrite2.withUnsafeBytes { bufferPtr in 
                    var overlapped = WindowsOverlapped()
                    let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(pendingOverlapped)
                }

                #expect(bytesWritten2 == 7)
                #expect(try handle.tell() == 0)
                #expect(try Data(contentsOf: URL(fileURLWithPath: path.string)) == Data("Hoshinoerika!".utf8))
            }

            do {
                let dataToWrite = Data(" is cute".utf8)

                let bytesWritten = try dataToWrite.withUnsafeBytes { bufferPtr in 
                    var overlapped = WindowsOverlapped(offset: 7)
                    let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                    return try handle.waitForOverlappedResult(pendingOverlapped)
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