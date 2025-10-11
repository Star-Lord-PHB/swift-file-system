import Testing
import SystemPackage
import Foundation
@testable import FileSystem


@Suite
final class FileSystemTest {

    static let rootDir: FilePath = .init(URL.temporaryDirectory.path).appending("swift-file-system-tests")

    let testId: String
    
    var testDir: FilePath { Self.rootDir.appending(testId.description) }


    init() throws {
        let test = try #require(Test.current, "Must be run inside a test")
        self.testId = "\(test.id)-\(UUID().uuidString)"
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "_")
        try FileManager.default.createDirectory(at: .init(filePath: testDir.string), withIntermediateDirectories: true)
    }


    deinit {
        try? FileManager.default.removeItem(at: .init(filePath: testDir.string))
    }


    func makeFile(at path: FilePath, contents: Data = .init()) throws -> FilePath {

        precondition(path.isRelative, "Path must be relative")

        let absPath = testDir.appending(path.components)

        if (path.components.count > 1) {
            let parent = absPath.removingLastComponent()
            try FileManager.default.createDirectory(at: .init(filePath: parent.string), withIntermediateDirectories: true)
        }

        try contents.write(to: .init(filePath: absPath.string))

        return absPath

    }


    func makeSymlink(at path: FilePath, pointingTo target: FilePath) throws -> FilePath {

        precondition(path.isRelative, "Path must be relative")

        let absPath = testDir.appending(path.components)

        let parent = absPath.removingLastComponent()
        try FileManager.default.createDirectory(at: .init(filePath: parent.string), withIntermediateDirectories: true)

        try FileManager.default.createSymbolicLink(atPath: absPath.string, withDestinationPath: target.string)

        return absPath

    }


    func makeDir(at path: FilePath) throws -> FilePath {

        precondition(path.isRelative, "Path must be relative")

        let absPath = testDir.appending(path.components)
        try FileManager.default.createDirectory(at: .init(filePath: absPath.string), withIntermediateDirectories: true)

        return absPath

    }


    @Test
    func test1() async throws {
        
        let path = try makeFile(at: "file.txt")

        let info = try FileInfo(fileAt: path)
        // print(info)

        let attributes = try FileManager.default.attributesOfItem(atPath: path.string)
        let urlAttributes = try URL(filePath: path.string).resourceValues(forKeys: [.creationDateKey, .contentAccessDateKey])
        // print(attributes)

        #expect(info.size == attributes[.size] as? UInt64)

        if let date = info.creationDate?.date, let expectedCreationDate = urlAttributes.creationDate {
            #expect(date.timeIntervalSince(expectedCreationDate) < 1e-6)
        } else {
            #expect(info.creationDate?.date == urlAttributes.creationDate)
        }
        #expect(info.lastModificationDate.date == attributes[.modificationDate] as? Date)
        #expect(info.lastAccessDate.date == urlAttributes.contentAccessDate)

        #expect(info.owner.uid == attributes[.ownerAccountID] as? UInt32)
        #expect(info.owner.gid == attributes[.groupOwnerAccountID] as? UInt32)

    }


    @Test
    func test2() async throws {
        
        let path = try makeFile(at: "file.txt")
        let link = try makeSymlink(at: "link.txt", pointingTo: path)

        let linkInfo = try FileInfo(fileAt: link, followSymLink: false)
        print(linkInfo)
        #expect(linkInfo.type == .symlink)

        let targetInfo = try FileInfo(fileAt: link, followSymLink: true)
        print(targetInfo)

    }


    @Test
    func test3() async throws {
        
        let path = "not-exists.txt" as FilePath

        #expect(throws: FileError.self) {
            _ = try FileInfo(fileAt: path)
        }

    }

}
