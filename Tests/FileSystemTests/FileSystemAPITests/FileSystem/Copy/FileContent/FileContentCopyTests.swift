import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    /// Byte-for-byte fidelity of the file content copy across block boundaries.
    @Suite("File content")
    struct FileContentCopyTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.FileContentCopyTests {

    /// Sizes on both sides of the block size and well beyond it. Windows copies a file whole
    /// and has no block size, so its table keeps only the sizes that do not derive from one.
    static var contentSizes: [Int] {
        #if canImport(WinSDK)
        return [0, 1, (8 << 20) + 4097, 20 << 20]
        #else
        let chunk = CopyTests.contentCopyChunkSize
        return [0, 1, chunk - 1, chunk, chunk + 1, (8 << 20) + 4097, 20 << 20]
        #endif
    }


    @Test(arguments: contentSizes)
    func `Copies file contents exactly`(byteCount: Int) throws {

        let src = try workspace.makeLargeFile(at: "src.bin", byteCount: byteCount)
        let dst = workspace.path("dst.bin")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }

}
