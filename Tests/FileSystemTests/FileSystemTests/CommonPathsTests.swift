import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    @Suite
    final class CommonPathsTests: FileSystemTest {}
    
}



extension FileSystemTest.CommonPathsTests {

    @Test("Current Working Directory")
    func currentWorkingDirectory() async throws {
        let cwd = try FileSystem().currentWorkingDirectoryPath()
        #expect(cwd == FilePath(FileManager.default.currentDirectoryPath))
    }


    @Test("Executable Path")
    func executablePath() async throws {
        let executable = try FileSystem().executablePath()
        #expect(executable == Bundle.main.executablePath.map { FilePath($0) })
    }


    @Test("Home Directory")
    func homeDirectory() async throws {
        let home = try FileSystem().homeDirectoryPath()
        #expect(home == FilePath(FileManager.default.homeDirectoryForCurrentUser.path))
    }


    @Test("Temp Directory")
    func tempDirectory() async throws {
        let temp = try FileSystem().tempDirectoryPath()
        #expect(temp == FilePath(FileManager.default.temporaryDirectory.path))
    }


    @Test("Cache Directory")
    func cacheDirectory() async throws {
        let cache = try FileSystem().cacheDirectoryPath()
        #if canImport(WinSDK)
        let expectedCache = FilePath(try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).path)
        #else
        let expectedCache = FilePath(try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false).path)
        #endif
        #expect(cache == expectedCache)
    }

}