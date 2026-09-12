import Foundation
import SystemPackage
import Testing
import FileSystemCore

@testable import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    /// White-box tests of the copy session: one `copyStep()` advances one directory entry or one
    /// content block, and the state between steps is observable.
    @Suite("Session steps")
    struct CopySessionStepTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.CopySessionStepTests {

    private func entryCount(of directory: FilePath) throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: directory.string).count
    }


    @Test
    func `A small tree completes in one step per entry plus the file content steps`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "a.txt": .file(contents: "a contents"),
                "link": .symlink(target: "a.txt"),
                "sub": [
                    "b.txt": .file(contents: "b contents")
                ],
                "empty": [:],
            ]
        )
        let dst = workspace.path("dst")
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: .init(),
            errorStrategy: .collectAndReturn
        )

        #expect(handler.copyStep() == .paused)
        #expect(CopyTests.sessionState(of: handler) == .copying(hasDirectory: true, hasFile: false))
        // A file takes one step to register and then its content steps: one per block plus the
        // one that reads the end of the file on POSIX, or one for the whole file on Windows.
        #if canImport(WinSDK)
        let stepsPerSmallFile = 2
        #else
        let stepsPerSmallFile = 3
        #endif
        // After the root's own step above, every entry takes one step, a subdirectory another
        // when it is left, and the root one more when its enumeration ends.
        #expect(try CopyTests.stepToCompletion(&handler) == 2 * stepsPerSmallFile + 1 + 2 * 2 + 1)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: false))
        #expect(handler.errorCollector.errors.value == nil)
        // A step after completion changes nothing.
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: false))
        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)

    }

}



#if !canImport(WinSDK)
extension FileSystemAPITests.CopyTests.CopySessionStepTests {

    @Test
    func `A root file to a missing target is created empty and filled one block per step`() throws {

        let chunk = CopyTests.contentCopyChunkSize
        let src = try workspace.makeLargeFile(at: "src.bin", byteCount: 2 * chunk + 1)
        let container = try workspace.makeDirectory(at: "container")
        let dst = container.appending("dst.bin")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: .init(),
            errorStrategy: .collectAndReturn
        )

        #expect(handler.copyStep() == .paused)
        #expect(CopyTests.sessionState(of: handler) == .copying(hasDirectory: false, hasFile: true))
        // The target is created directly and empty; nothing is staged beside it.
        #expect(try Support.ItemMetadata.capture(at: dst).size == 0)
        #expect(try entryCount(of: container) == 1)
        #expect(handler.copyStep() == .paused)
        #expect(try Support.ItemMetadata.capture(at: dst).size == UInt64(chunk))
        // Two more blocks, then the step that reads the end of the file and finishes.
        #expect(try CopyTests.stepToCompletion(&handler) == 3)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: false))
        #expect(try entryCount(of: container) == 1)
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `A root file over an existing target is staged beside it until completion`() throws {

        let chunk = CopyTests.contentCopyChunkSize
        let src = try workspace.makeLargeFile(at: "src.bin", byteCount: 2 * chunk + 1)
        let dst = try workspace.makeFile(at: "container/dst.bin", contents: "existing contents")
        let container = dst.removingLastComponent()
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dstSnapshot = try Support.ItemSnapshot.capture(at: dst)
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(existingTarget: .overwrite),
            cancellationToken: .init(),
            errorStrategy: .collectAndReturn
        )

        #expect(handler.copyStep() == .paused)
        #expect(CopyTests.sessionState(of: handler) == .copying(hasDirectory: false, hasFile: true))
        // The staged file appears with the registration, before any content step, and stays
        // the only extra entry: cleanup after an abort or a cancellation relies on that.
        #expect(try entryCount(of: container) == 2)
        #expect(handler.copyStep() == .paused)
        #expect(try entryCount(of: container) == 2)
        // The target is untouched while the blocks go to the staged file.
        try Support.expectItem(at: dst, matches: dstSnapshot, using: .unchanged)
        #expect(try CopyTests.stepToCompletion(&handler) == 3)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: false))
        #expect(try entryCount(of: container) == 1)
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }

}
#endif



#if canImport(WinSDK)
extension FileSystemAPITests.CopyTests.CopySessionStepTests {

    @Test(arguments: [false, true], [false, true])
    func `A root file is copied whole in the step after its registration`(
        exactDacl: Bool, targetExists: Bool
    ) throws {

        let src = try workspace.makeLargeFile(at: "src.bin", byteCount: 3 << 20)
        let container = try workspace.makeDirectory(at: "container")
        let dst = container.appending("dst.bin")
        if targetExists {
            try workspace.makeFile(at: dst, contents: "existing contents")
        }
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            options: .init(existingTarget: .overwrite, windowsPreserveExactDacl: exactDacl),
            cancellationToken: .init(),
            errorStrategy: .collectAndReturn
        )

        #expect(handler.copyStep() == .paused)
        #expect(CopyTests.sessionState(of: handler) == .copying(hasDirectory: false, hasFile: true))
        // Registration only records the task; nothing is staged before the content step.
        #expect(try entryCount(of: container) == (targetExists ? 1 : 0))
        // There is no partial state: the content step copies the whole file and finishes.
        #expect(handler.copyStep() == .completed)
        #expect(CopyTests.sessionState(of: handler) == .ended(cancelled: false))
        #expect(try entryCount(of: container) == 1)
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }

}
#endif
