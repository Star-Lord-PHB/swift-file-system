import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Common paths")
    struct CommonPathsTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()

    }

}



extension FileSystemAPITests.CommonPathsTests {

    private func expectEquivalentPath(
        _ actual: FilePath,
        expected expectedURL: URL,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try expectEquivalentPath(
            actual, 
            expected: expectedURL.path, 
            sourceLocation: sourceLocation
        )
    }


    private func expectEquivalentPath(
        _ actual: FilePath,
        expected: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let expected = FilePath(expected)
        let comment = "Expected \(actual) to be equivalent to \(expected)" as Comment

        #expect(!actual.isRelative, comment, sourceLocation: sourceLocation)
        #expect(!expected.isRelative, comment, sourceLocation: sourceLocation)

        let standardizedActual = standardizedPath(actual)
        let standardizedExpected = standardizedPath(expected)
        guard standardizedActual != standardizedExpected else { return }

        guard
            FileManager.default.fileExists(atPath: actual.string),
            FileManager.default.fileExists(atPath: expected.string)
        else {
            #expect(
                standardizedActual == standardizedExpected,
                comment, sourceLocation: sourceLocation
            )
            return
        }

        let actualID = try Support.ItemMetadata.captureIdentifier(
            at: actual,
            followSymlink: true,
            sourceLocation: sourceLocation
        )
        let expectedID = try Support.ItemMetadata.captureIdentifier(
            at: expected,
            followSymlink: true,
            sourceLocation: sourceLocation
        )
        #expect(actualID == expectedID, comment, sourceLocation: sourceLocation)
    }


    private func standardizedPath(_ path: FilePath) -> FilePath {
        .init(URL(filePath: path.string).standardizedFileURL.path(percentEncoded: false))
    }


    @Test
    func `Current working dir matches Foundation`() throws {

        let path = try fileSystem.currentWorkingDirectoryPath()
        let expected = FileManager.default.currentDirectoryPath

        try expectEquivalentPath(path, expected: expected)

    }


    @Test
    func `Executable path matches the main bundle`() throws {

        let path = try fileSystem.executablePath()
        let expected = try #require(Bundle.main.executableURL)

        try expectEquivalentPath(path, expected: expected)

    }


    @Test
    func `Home dir matches Foundation`() throws {

        let path = try fileSystem.homeDirectoryPath()
        let expected = FileManager.default.homeDirectoryForCurrentUser

        try expectEquivalentPath(path, expected: expected)

    }


    @Test
    func `Temp dir matches Foundation`() throws {

        let path = try fileSystem.tempDirectoryPath()
        let expected = FileManager.default.temporaryDirectory

        try expectEquivalentPath(path, expected: expected)

    }


    @Test
    func `Cache dir matches Foundation`() throws {

        let path = try fileSystem.cacheDirectoryPath()

        #if canImport(WinSDK)
        let fileManagerSearchDir = FileManager.SearchPathDirectory.applicationSupportDirectory
        #else
        let fileManagerSearchDir = FileManager.SearchPathDirectory.cachesDirectory
        #endif
        
        let expected = try FileManager.default.url(
            for: fileManagerSearchDir,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        try expectEquivalentPath(path, expected: expected)

    }

}
