import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class Lab: FileSystemTest {}

}



extension FileSystemTest.Lab {

    @Test("Lab 1")
    func lab1() async throws {
        
        // let dir = try makeDir(at: "dir")
        // let link = try makeSymlink(at: "link", pointingTo: dir)

        // try InternalFS.rmdir(at: link)

        // print(try FileInfo(fileAt: link, followSymLink: false).type)
        // print(try FileInfo(fileAt: dir, followSymLink: false).type)

    }

}