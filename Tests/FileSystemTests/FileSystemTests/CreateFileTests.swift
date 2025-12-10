import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class CreateFileTest: FileSystemTest {}

}



extension FileSystemTest.CreateFileTest {

    @Test("Dst Not Exist, default permission, empty content")
    func createFileDstNotExistDefaultEmptyContent() async throws {
        
        let path = makePath(at: "newFile")

        try FileSystem().createFile(at: path)

        let info = try FileInfo(fileAt: path)

        #expect(info.type == .regular)
        #expect(info.size == 0)

        #if canImport(WinSDK)
        // TODO: Check default permission on Windows
        #else 
        #expect(info.securityInfo.permission == [.ownerReadWrite, .groupRead, .otherRead])
        #endif 

        #expect(try Data(contentsOf: .init(filePath: path.string)) == .init())

    }


    @Test("Dst Not Exist, custom permission, custom content")
    func createFileDstNotExistCustomPermissionCustomContent() async throws {
        
        let path = makePath(at: "newFile")
        let permission = [.ownerReadWriteExecute, .groupReadWrite] as FilePermissions
        #if !canImport(WinSDK)
        let expectedPermission = {
            let originalUmask = umask(0)
            umask(originalUmask)
            return permission.subtracting(.init(rawValue: originalUmask))
        }()
        #endif
        let content = ByteBuffer("Hello, World!".utf8)

        try FileSystem().createFile(at: path, replaceExisting: false, permission: permission, content: content)

        let info = try FileInfo(fileAt: path)

        #expect(info.type == .regular)
        #expect(info.size == UInt64(content.count))

        #if canImport(WinSDK)
        // TODO: Check custom permission on Windows
        #else
        #expect(info.securityInfo.permission == expectedPermission)
        #endif

        #expect(try Data(contentsOf: .init(filePath: path.string)) == Data(content))
        
    }


    @Test("Dst Exist, replace existing, empty content")
    func createFileDstExistReplaceExistingEmptyContent() async throws {
        
        let path = try makeFile(at: "file", contents: .init("Hello Swift!".utf8))
        let prevInfo = try FileInfo(fileAt: path)

        try FileSystem().createFile(at: path, replaceExisting: true)

        let info = try FileInfo(fileAt: path)

        #expect(info.type == .regular)
        #expect(info.size == 0)
        #expect(try Data(contentsOf: .init(filePath: path.string)) == .init())

        #if canImport(WinSDK)
        // TODO: Check permission on Windows
        #else
        #expect(info.securityInfo.permission == prevInfo.securityInfo.permission)
        #endif

    }


    @Test("Dst Exist, replace existing, custom permission, custom content")
    func createFileDstExistReplaceExistingCustomPermissionCustomContent() async throws {
        
        let path = try makeFile(at: "file", contents: .init("Hello Swift!".utf8))
        let prevInfo = try FileInfo(fileAt: path)
        let permission = [.ownerReadWriteExecute, .groupReadWrite] as FilePermissions
        let content = ByteBuffer("Serika is Cute".utf8)

        try FileSystem().createFile(at: path, replaceExisting: true, permission: permission, content: content)

        let info = try FileInfo(fileAt: path)

        #expect(info.type == .regular)
        #expect(info.size == UInt64(content.count))
        #expect(try Data(contentsOf: .init(filePath: path.string)) == Data(content))

        #if canImport(WinSDK)
        // TODO: Check custom permission on Windows
        #else
        // when destination exists, the permission won't be updated
        #expect(info.securityInfo.permission == prevInfo.securityInfo.permission)
        #endif

    }


    @Test("Dst Exist, no replace")
    func createFileDstExistNoReplace() async throws {
        
        let path = try makeFile(at: "file", contents: .init("Hello Swift!".utf8))
        let prevInfo = try FileInfo(fileAt: path)

        let error = #expect(throws: FileError.self) {
            try FileSystem().createFile(at: path, replaceExisting: false)
        }

        #if canImport(WinSDK)
        #expect(error?.code == .alreadyExists)
        #else 
        #expect(error?.code == .fileExists)
        #endif

        let info = try FileInfo(fileAt: path)

        #expect(info == prevInfo)

    }

}