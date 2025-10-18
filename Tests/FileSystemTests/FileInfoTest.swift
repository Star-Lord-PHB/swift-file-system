import Testing
import SystemPackage
import Foundation
@testable import FileSystem


extension FileSystemTest {

    @Suite("FileInfo Tests")
    final class FileInfoTest: FileSystemTest {}

}



extension FileSystemTest.FileInfoTest {

    #if canImport(WinSDK)
    static let fileTimeAccuracy: TimeInterval = 1e-4
    var fileNotFoundErrorCode: FileError.PlatformErrorCode { .fileNotFound }
    #else
    static let fileTimeAccuracy: TimeInterval = 1e-6
    var fileNotFoundErrorCode: FileError.PlatformErrorCode { .noSuchFileOrDirectory }
    #endif

    func dateEquals(_ date1: Date?, _ date2: Date?, accuracy: TimeInterval = fileTimeAccuracy) -> Bool {
        switch (date1, date2) {
            case (nil, nil):
                return true
            case (let .some(d1), let .some(d2)):
                return abs(d1.timeIntervalSince(d2)) <= accuracy
            default:
                return false
        }
    }

}



extension FileSystemTest.FileInfoTest {

    @Test("Normal File")
    func normalFile() async throws {
        
        let content = Data("Hello, World!".utf8)
        let path = try makeFile(at: "test.txt", contents: content)

        let info = try FileInfo(fileAt: path)
        print(info)

        let attributes = try FileManager.default.attributesOfItem(atPath: path.string)
        let urlAttributes = try URL(filePath: path.string).resourceValues(forKeys: [.creationDateKey, .contentAccessDateKey])

        #expect(info.size == attributes[.size] as? UInt64)

        #expect(dateEquals(info.creationDate?.date, urlAttributes.creationDate))
        #expect(dateEquals(info.lastModificationDate.date, attributes[.modificationDate] as? Date))
        
        #if canImport(WinSDK)
        #expect(dateEquals(info.lastAccessDate.date, urlAttributes.contentAccessDate, accuracy: 1))
        #else
        #expect(dateEquals(info.lastAccessDate.date, urlAttributes.contentAccessDate))
        #endif

    }


    @Test("Directory")
    func directory() async throws {
        
        let path = try makeDir(at: "dir")

        let info = try FileInfo(fileAt: path)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: path.string)
        let urlAttributes = try URL(filePath: path.string).resourceValues(forKeys: [.creationDateKey, .contentAccessDateKey])

        #expect(info.size == attributes[.size] as? UInt64)
        #expect(info.type == .directory)

        #expect(dateEquals(info.creationDate?.date, urlAttributes.creationDate))
        #expect(dateEquals(info.lastModificationDate.date, attributes[.modificationDate] as? Date))

        #if canImport(WinSDK)
        #expect(dateEquals(info.lastAccessDate.date, urlAttributes.contentAccessDate, accuracy: 1))
        #else
        #expect(dateEquals(info.lastAccessDate.date, urlAttributes.contentAccessDate))
        #endif

    }


    @Test("Symbolic Link")
    func symbolicLink() async throws {
        
        let path = try makeFile(at: "file.txt")
        let link = try makeSymlink(at: "link.txt", pointingTo: path)

        let linkInfo = try FileInfo(fileAt: link, followSymLink: false)
        #expect(linkInfo.type == .symlink)

        let targetInfo = try FileInfo(fileAt: link, followSymLink: true)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: path.string)
        let urlAttributes = try URL(filePath: path.string).resourceValues(forKeys: [.creationDateKey, .contentAccessDateKey])

        #expect(targetInfo.size == attributes[.size] as? UInt64)
        #expect(targetInfo.type == .regular)

        #expect(dateEquals(targetInfo.creationDate?.date, urlAttributes.creationDate))
        #expect(dateEquals(targetInfo.lastModificationDate.date, attributes[.modificationDate] as? Date))

        #if canImport(WinSDK)
        #expect(dateEquals(targetInfo.lastAccessDate.date, urlAttributes.contentAccessDate, accuracy: 1))
        #else
        #expect(dateEquals(targetInfo.lastAccessDate.date, urlAttributes.contentAccessDate))
        #endif

    }


    @Test("Non Existing File")
    func nonExistingFile() async throws {
        
        let path = "not-exists.txt" as FilePath

        let error = #expect(throws: FileError.self) {
            _ = try FileInfo(fileAt: path)
        }

        let errorCode = try #require(error?.code)
        #expect(errorCode == fileNotFoundErrorCode)

    }


    @Test("Non Existing Link Target")
    func nonExistingLinkTarget() async throws {

        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.txt", pointingTo: targetPath)

        try FileManager.default.removeItem(atPath: targetPath.string)

        let error = #expect(throws: FileError.self) {
            _ = try FileInfo(fileAt: linkPath, followSymLink: true)
        }

        let errorCode = try #require(error?.code)
        #expect(errorCode == fileNotFoundErrorCode)

    }

}