import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Regular file")
    struct RegularFileCopyTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.RegularFileCopyTests {

    @Test
    func `Copies contents and metadata to a missing destination`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "copied contents")
        let dst = workspace.path("dst.txt")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)
        // The copy reads the source, which pushes its access time on volumes that maintain it.
        try Support.expectItem(at: src, matches: srcSnapshot, using: .unchanged.excluding(.accessTime))

    }


    @Test
    func `Copies an empty file`() throws {

        let src = try workspace.makeFile(at: "empty.txt")
        let dst = workspace.path("dst.txt")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `Copies large contents exactly`() throws {

        var contents = Data(count: 1_000_003)
        for index in stride(from: 0, to: contents.count, by: 4096) {
            contents[index] = UInt8(truncatingIfNeeded: index >> 12)
        }
        let src = try workspace.makeFile(at: "large.bin", contents: contents)
        let dst = workspace.path("dst.bin")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test(arguments: [.overwrite, .skip, .error] as [FileOperationOptions.CopyTargetExistOption])
    func `Copies to a missing destination regardless of existing-target option`(
        option: FileOperationOptions.CopyTargetExistOption
    ) throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "copied contents")
        let dst = workspace.path("dst.txt")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: option))

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }

}
