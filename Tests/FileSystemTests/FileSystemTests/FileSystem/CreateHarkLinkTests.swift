import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore

#if canImport(WinSDK)
import WinSDK
#endif



extension FileSystemTest {

    final class CreateHardLinkTest: FSIsolatedTestCase {

        func expectIdentical(path1: FilePath, path2: FilePath, sourceLocation: SourceLocation = #_sourceLocation) throws {

            #if canImport(WinSDK)

            let handle1 = path1.withPlatformString { pathPtr in 
                CreateFileW(
                    pathPtr,
                    DWORD(READ_ATTRIBUTES | READ_CONTROL),
                    DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                    nil,
                    DWORD(OPEN_EXISTING),
                    DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS),
                    nil
                )
            }
            try #require(handle1 != INVALID_HANDLE_VALUE, "Failed to open file at path: \(path1)", sourceLocation: sourceLocation)

            defer {
                CloseHandle(handle1)
            }

            let handle2 = path2.withPlatformString { pathPtr in 
                CreateFileW(
                    pathPtr,
                    DWORD(READ_ATTRIBUTES | READ_CONTROL),
                    DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                    nil,
                    DWORD(OPEN_EXISTING),
                    DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS),
                    nil
                )
            }
            try #require(handle2 != INVALID_HANDLE_VALUE, "Failed to open file at path: \(path2)", sourceLocation: sourceLocation)

            defer {
                CloseHandle(handle2)
            }

            var idInfo1 = FILE_ID_INFO()
            var idInfo2 = FILE_ID_INFO()

            try #require(
                GetFileInformationByHandleEx(handle1, FileIdInfo, &idInfo1, DWORD(MemoryLayout<FILE_ID_INFO>.size)), 
                "Failed to get file information for path: \(path1)", 
                sourceLocation: sourceLocation
            )
            try #require(
                GetFileInformationByHandleEx(handle2, FileIdInfo, &idInfo2, DWORD(MemoryLayout<FILE_ID_INFO>.size)), 
                "Failed to get file information for path: \(path2)", 
                sourceLocation: sourceLocation
            )

            #expect(idInfo1.FileId.uint128 == idInfo2.FileId.uint128, sourceLocation: sourceLocation)
            #expect(idInfo1.VolumeSerialNumber == idInfo2.VolumeSerialNumber, sourceLocation: sourceLocation)

            #else 

            var stat1 = stat()
            var stat2 = stat()

            try #require(lstat(path1.string, &stat1) == 0, sourceLocation: sourceLocation)
            try #require(lstat(path2.string, &stat2) == 0, sourceLocation: sourceLocation)

            #expect(stat1.st_ino == stat2.st_ino, sourceLocation: sourceLocation)

            #endif 

        }

    }

}



extension FileSystemTest.CreateHardLinkTest {

    @Test("Hard Link Existing File")
    func hardLinkExistingFile() async throws {
        
        let existingPath = try makeFile(at: "file", contents: .init("Hello, World!".utf8))
        let hardLinkParh = makePath(at: "link")

        try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)

        try expectIdentical(path1: existingPath, path2: hardLinkParh)

    }


    @Test("Hard Link Existing Symlink")
    func hardLinkExistingSymlink() async throws {
        
        let existingPath = try makeSymlink(at: "symlink", pointingTo: "target")
        let hardLinkParh = makePath(at: "link")

        try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)

        try expectIdentical(path1: existingPath, path2: hardLinkParh)

    }


    @Test("Hard Link Existing Directory")
    func hardLinkExistingDirectory() async throws {
        
        let existingPath = try makeDir(at: "directory")
        let hardLinkParh = makePath(at: "link")

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .system(.accessDenied))
        #else
        #expect(error?.code == .system(.operationNotPermitted))
        #endif

    }


    @Test("Hard Link Non-Existing Item")
    func hardLinkNonExistingItem() async throws {
        
        let existingPath = makePath(at: "non-existing")
        let hardLinkParh = makePath(at: "link")

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)
        }

        #expect(error?.code == .fileNotFound)

    }


    @Test("Hard Link Item Already Exists")
    func hardLinkItemAlreadyExists() async throws {
        
        let existingPath = try makeFile(at: "file", contents: .init("Hello, World!".utf8))
        let hardLinkParh = try makeFile(at: "link", contents: .init("Existing File".utf8))

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().createHardLink(at: hardLinkParh, for: existingPath)
        }

        #expect(error?.kind == .alreadyExists)

    }

}