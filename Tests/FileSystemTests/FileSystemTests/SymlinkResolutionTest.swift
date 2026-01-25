import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore


extension FileSystemTest {

    @Suite(.disabled())
    final class _ExperimentalSymlinkResolutionTest: FileSystemTest {}

}



extension FileSystemTest._ExperimentalSymlinkResolutionTest {

    @Test("Recursive (Single Level at End)")
    func recursiveSingleLevelAtEnd() async throws {
        
        let targetPath = try makeFile(at: "target.txt")
        let linkPath = try makeSymlink(at: "link.lnk", pointingTo: "target.txt")

        let resolvedTarget = try FileSystem().destinationOfSymLink(at: linkPath, recursive: true)
        
        #if canImport(WinSDK)
        // On Windows, due to the limitation of URL, there is currently no good way to get the path root starts with "\\?\".
        // So currently we are manually removing this prefix for comparison
        let expectedResolvedPathUrl = URL(filePath: linkPath.string).resolvingSymlinksInPath().standardizedFileURL
        var transformedResolvedTarget = resolvedTarget
        transformedResolvedTarget.root = .init(resolvedTarget.root?.string.dropFirst(4).description ?? "")
        var expectedResolvedPath = FilePath(expectedResolvedPathUrl.pathComponents.dropFirst().joined(separator: "/"))
        #expect(transformedResolvedTarget == expectedResolvedPath)
        #else
        // The resolveingSymlinksInPath on Darwin does not work correctly, so we are suing realpath here directly
        var buffer = [CChar](repeating: 0, count: 4096)     // 4096 bytes should be enough even for platforms without actual path length limit
        realpath(targetPath.string, &buffer)
        let expectedResolvedPath = FilePath(platformString: buffer)
        #expect(resolvedTarget == expectedResolvedPath)
        #endif

    }


    @Test("Recursive (Multi Level at Middle and End)")
    func recursiveMultiLevelAtMiddleAndEnd() async throws {
        
        let dirAPath = try makeDir(at: "dirA")
        let dirBPath = try makeDir(at: "dirA/dirB")
        let dirCPath = try makeDir(at: "dirA/dirB/dirC")
        let targetPath = try makeFile(at: "dirA/dirB/dirC/target.txt")
        let dirALink1Path = try makeSymlink(at: "linkA1.lnk", pointingTo: dirAPath)                 // absolute symlink
        let dirALink2Path = try makeSymlink(at: "linkA2.lnk", pointingTo: "linkA1.lnk")             // relative symlink
        let dirBLinkPath = try makeSymlink(at: "dirA/linkB.lnk", pointingTo: "../dirA/./dirB")      // relative symlink with ".." and "."
        let targetLinkPath = try makeSymlink(at: "dirA/dirB/link.lnk", pointingTo: "dirC/target.txt")

        // silence unused variable warnings
        _ = (dirBPath, targetPath, dirCPath, dirALink1Path, dirALink2Path, dirBLinkPath, targetLinkPath)

        let pathToResolve = testDir.appending("linkA2.lnk/linkB.lnk/link.lnk")

        let t1 = try ContinuousClock.continuous.measure {
            _ = try FileSystem().__symlinkRecursiveDestination(of: pathToResolve)
        }

        let t2 = ContinuousClock.continuous.measure {
            var buffer = [CChar](repeating: 0, count: 4096)     // 4096 bytes should be enough even for platforms without actual path length limit
            realpath(targetPath.string, &buffer)
            let _ = FilePath(platformString: buffer)
        }

        print("custom resolve: \(t1)")
        print("realpath:       \(t2)")

        let resolvedTarget = try FileSystem().destinationOfSymLink(at: pathToResolve, recursive: true)
        
        #if canImport(WinSDK)
        // On Windows, due to the limitation of URL, there is currently no good way to get the path root starts with "\\?\".
        // So currently we are manually removing this prefix for comparison
        let expectedResolvedPathUrl = URL(filePath: pathToResolve.string).resolvingSymlinksInPath().standardizedFileURL
        var transformedResolvedTarget = resolvedTarget
        transformedResolvedTarget.root = .init(resolvedTarget.root?.string.dropFirst(4).description ?? "")
        var expectedResolvedPath = FilePath(expectedResolvedPathUrl.pathComponents.dropFirst().joined(separator: "/"))
        #expect(transformedResolvedTarget == expectedResolvedPath)
        #else
        var buffer = [CChar](repeating: 0, count: 4096)     // 4096 bytes should be enough even for platforms without actual path length limit
        realpath(targetPath.string, &buffer)
        let expectedResolvedPath = FilePath(platformString: buffer)
        #expect(resolvedTarget == expectedResolvedPath)
        #endif

    }

}