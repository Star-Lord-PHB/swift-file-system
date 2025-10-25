import Testing
import SystemPackage
import Foundation
@testable import FileSystem

#if canImport(WinSDK)
import WinSDK
#endif 


// Tests of the FileSystem APIs will include resource handle leakage check, which does not work correctly
// in parallel testing
@Suite(.serialized)
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


    func makePath(at path: FilePath) -> FilePath {
        precondition(path.isRelative, "Path must be relative")
        return testDir.appending(path.components)
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


    func currentOpenedHandleCount() -> Int64 {

        #if canImport(WinSDK)

        var count = 0 as DWORD
        GetProcessHandleCount(GetCurrentProcess(), &count)
        return Int64(count)

        #elseif canImport(Darwin)

        return Int(proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, nil, 0)) / MemoryLayout<proc_fdinfo>.size

        #else

        var count = 0 as Int64
        let procFdDir = #require(opendir("/proc/self/fd"))
        defer { closedir(procFdDir) }
        while readdir(procFdDir) != nil {
            count += 1
        }
        return count - 2

        #endif

    }


    func expectNoResHandleLeak<R>(
        sourceLocation: SourceLocation = #_sourceLocation,
        operation: () async throws -> sending R
    ) async throws -> sending R {

        let openedHandleCountBefore = currentOpenedHandleCount()
        let result = try await operation()
        let openedHandleCountAfter = currentOpenedHandleCount()

        #expect(
            openedHandleCountBefore == openedHandleCountAfter, 
            "The num of resource handle opened before and after running the operation should be identical", 
            sourceLocation: sourceLocation
        )

        return result

    }


    func expectNoResHandleLeak<R>(
        sourceLocation: SourceLocation = #_sourceLocation,
        operation: () async throws -> sending R,
        preheat: () async throws -> Void
    ) async throws -> sending R {

        try await preheat()

        let openedHandleCountBefore = currentOpenedHandleCount()
        let result = try await operation()
        let openedHandleCountAfter = currentOpenedHandleCount()

        #expect(
            openedHandleCountBefore == openedHandleCountAfter, 
            "The num of resource handle opened before and after running the operation should be identical", 
            sourceLocation: sourceLocation
        )

        return result

    }

}
