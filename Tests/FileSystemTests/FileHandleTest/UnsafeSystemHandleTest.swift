import Testing
import SystemPackage
import Foundation
@testable import FileSystem

#if canImport(WinSDK)
import WinSDK
#endif 



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

        } preheat: {
            // Preheat for Windows, where the #expect macro itself will open a handle when an error is captured for some reason
            #expect(throws: SystemError.self) {
                throw SystemError(code: 1)
            }
        }

    }


    @Test("Open for Writing (File not Exist, Create)")
    func openForWriting5() async throws {
        
        let path = makePath(at: "test.txt")

        #if canImport(WinSDK)
        // On Windows, the resource handle leak is not checked since it uses some APIs related to security descriptor, 
        // which creates some additional handles that we cannot detect.
        do {

            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(
                    access: .writeOnly, 
                    creation: .createIfMissing
                ),
                creationPermissions: [.ownerReadWrite, .otherRead]
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
        #else 
        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(
                at: path, 
                openOptions: .init(
                    access: .writeOnly, 
                    creation: .createIfMissing
                ),
                creationPermissions: [.ownerReadWrite, .otherRead]
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
        #endif 

        do {
            let finalContents = try String(contentsOf: .init(fileURLWithPath: path.string), encoding: .utf8)
            #expect(finalContents == "Hello Swift!")
        }

    }


    @Test("Open for Writing (File Exist, Create)")
    func openForWriting6() async throws {
        
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


    @Test("Open for Writing (File not Exist, No Permission)")
    func openForWriting7() async throws {
        
        let path = makePath(at: "test.txt")

        #if canImport(WinSDK)
        // On Windows, the resource handle leak is not checked since it uses some APIs related to security descriptor,
        // which creates some additional handles that we cannot detect.
        do {

            do {
                // First, create this file with no permission at all
                let handle = try UnsafeSystemHandle.open(
                    at: path, 
                    openOptions: .init(
                        access: .writeOnly, 
                        creation: .createIfMissing
                    ),
                    creationPermissions: []
                )

                // Write something to it
                let data = Data("Hello".utf8)
                try data.withUnsafeBytes { bufferPtr in 
                    _ = try handle.write(contentsOf: bufferPtr)
                }
            }

            // Now, try to open it again 
            let error = try #require(throws: SystemError.self) {
                let _ = try UnsafeSystemHandle.open(
                    at: path, 
                    openOptions: .init(
                        access: .writeOnly, 
                        creation: .createIfMissing
                    )
                )
            }

            #expect(error.code == ERROR_ACCESS_DENIED)

        }
        #else 
        try await expectNoResHandleLeak {

            do {
                // First, create this file with no permission at all
                let handle = try UnsafeSystemHandle.open(
                    at: path, 
                    openOptions: .init(
                        access: .writeOnly, 
                        creation: .createIfMissing
                    ),
                    creationPermissions: []
                )

                // Write something to it
                let data = Data("Hello".utf8)
                try data.withUnsafeBytes { bufferPtr in 
                    _ = try handle.write(contentsOf: bufferPtr)
                }
            }

            try withKnownIssue(
                "When the current user is root, this test is meaningless", 
                {
                    // Now, try to open it again 
                    let error = try #require(throws: SystemError.self) {
                        let _ = try UnsafeSystemHandle.open(
                            at: path, 
                            openOptions: .init(
                                access: .writeOnly, 
                                creation: .createIfMissing
                            )
                        )
                    }
                    #expect(error.code == EACCES)
                }, 
                when: { getuid() == 0 }
            )

        }
        #endif

    }


    @Test("Open for Reading (Error: Read op on Dir)")
    func openForReadingAndReadDir() async throws {
        
        let dirPath = try makeDir(at: "dir")

        try await expectNoResHandleLeak {

            let handle = try UnsafeSystemHandle.open(
                at: dirPath, 
                openOptions: .init(
                    access: .readOnly(), 
                    platformSpecificOptions: [.windows.backupSemantics, .posix.directoryOnly]
                )
            )

            let error = try #require(throws: SystemError.self) {
                var buffer = Data(count: 10)
                try buffer.withUnsafeMutableBytes { bufferPtr in 
                    _ = try handle.read(into: bufferPtr)
                }
            }

            #if canImport(WinSDK)
            #expect(error.code == ERROR_INVALID_FUNCTION)
            #else
            #expect(error.code == EISDIR)
            #endif

        }

    }


    #if canImport(WinSDK)

    @Test("Open for Reading (Error: No Access to Dir)")
    func openForReadingNoAccessToDir() async throws {
        
        let dirPath = try makeDir(at: "dir")

        try await expectNoResHandleLeak {

            let error = try #require(throws: SystemError.self) {
                let _ = try UnsafeSystemHandle.open(
                    at: dirPath, 
                    openOptions: .init(
                        access: .readOnly(), 
                        platformSpecificOptions: []       // .windowsBackupSemantics flag (i.e.: FILE_FLAG_BACKUP_SEMANTICS) is NOT set here
                    )
                )
            }

            #expect(error.code == ERROR_ACCESS_DENIED)

        }

    }

    #else
    
    @Test("Open for reading (Error: Not a Dir)")
    func openForReadingNotADir() async throws {
        
        let filePath = try makeFile(at: "test.txt")

        try await expectNoResHandleLeak {

            let error = try #require(throws: SystemError.self) {
                let _ = try UnsafeSystemHandle.open(
                    at: filePath, 
                    openOptions: .init(
                        access: .readOnly(), 
                        platformSpecificOptions: [.posix.directoryOnly]
                    )
                )
            }

            #expect(error.code == ENOTDIR)

        }

    }
    #endif

}