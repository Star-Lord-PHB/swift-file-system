import Testing
import SystemPackage
import Foundation
@testable import FileSystem


@Suite
class FileSystemTest {

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

}
