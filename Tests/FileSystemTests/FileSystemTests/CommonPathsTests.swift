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
        #expect(cwd.string == FileManager.default.currentDirectoryPath)
    }


    @Test("Executable Path")
    func executablePath() async throws {
        let executable = try FileSystem().executablePath()
        #expect(executable.string == Bundle.main.executablePath)
    }


    @Test("Home Directory")
    func homeDirectory() async throws {
        let home = try FileSystem().homeDirectoryPath()
        #expect(home.string == FileManager.default.homeDirectoryForCurrentUser.path)
    }


    @Test("Temp Directory")
    func tempDirectory() async throws {
        let temp = try FileSystem().tempDirectoryPath()
        #expect(temp.string == FileManager.default.temporaryDirectory.path)
    }


    @Test("Cache Directory")
    func cacheDirectory() async throws {
        let cache = try FileSystem().cacheDirectoryPath()
        let expectedCache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false).path
        #expect(cache.string == expectedCache)
    }

}