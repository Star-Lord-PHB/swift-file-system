import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Root errors")
    struct RootErrorTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.RootErrorTests {

    @Test
    func `A missing source copies nothing under every strategy`() throws {

        let src = workspace.path("missing-src")
        let dstAbort = workspace.path("dst-abort")
        let dstThrow = workspace.path("dst-throw")
        let dstReturn = workspace.path("dst-return")
        let dstIgnore = workspace.path("dst-ignore")

        let abortError = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(at: src, to: dstAbort, errorStrategy: .abortOnError)
        }
        #expect(abortError?.kind == .notFound)

        let thrownReport = try CopyTests.requireThrownReport {
            try fileSystem.copyItem(at: src, to: dstThrow)
        }
        try CopyTests.expectReport(
            thrownReport,
            srcRoot: src,
            dstRoot: dstThrow,
            errors: [("", .getSrcMetadata, .notFound)]
        )

        let returnedReport = fileSystem.copyItem(
            at: src,
            to: dstReturn,
            errorStrategy: .collectAndReturn
        )
        try CopyTests.expectReport(
            returnedReport,
            srcRoot: src,
            dstRoot: dstReturn,
            errors: [("", .getSrcMetadata, .notFound)]
        )

        fileSystem.copyItem(at: src, to: dstIgnore, errorStrategy: .ignoreAll)

        for dst in [dstAbort, dstThrow, dstReturn, dstIgnore] {
            try Support.expectItemNotExistNoFollow(at: dst)
        }

    }


    @Test
    func `An unsupported root copies nothing under every strategy`() throws {

        #if canImport(WinSDK)
        // A junction: a name-surrogate reparse point that is not a symlink.
        let junctionTarget = try workspace.makeDirectory(at: "junction-target")
        let src = workspace.path("src-junction")
        try Support.makeWindowsJunction(at: src, pointingTo: junctionTarget)
        #else
        let src = workspace.path("src-fifo")
        try #require(mkfifo(src.string, 0o644) == 0)
        #endif
        let dstAbort = workspace.path("dst-abort")
        let dstThrow = workspace.path("dst-throw")
        let dstReturn = workspace.path("dst-return")
        let dstIgnore = workspace.path("dst-ignore")

        let abortError = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(at: src, to: dstAbort, errorStrategy: .abortOnError)
        }
        #expect(abortError?.kind == .unsupported)

        let thrownReport = try CopyTests.requireThrownReport {
            try fileSystem.copyItem(at: src, to: dstThrow)
        }
        try CopyTests.expectReport(
            thrownReport,
            srcRoot: src,
            dstRoot: dstThrow,
            errors: [("", .copyContents, .unsupported)]
        )

        let returnedReport = fileSystem.copyItem(
            at: src,
            to: dstReturn,
            errorStrategy: .collectAndReturn
        )
        try CopyTests.expectReport(
            returnedReport,
            srcRoot: src,
            dstRoot: dstReturn,
            errors: [("", .copyContents, .unsupported)]
        )

        fileSystem.copyItem(at: src, to: dstIgnore, errorStrategy: .ignoreAll)

        for dst in [dstAbort, dstThrow, dstReturn, dstIgnore] {
            try Support.expectItemNotExistNoFollow(at: dst)
        }

    }


    @Test
    func `A missing destination parent copies nothing under every strategy`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file")
            ]
        )
        let dstAbort = workspace.path("missing-abort/dst")
        let dstThrow = workspace.path("missing-throw/dst")
        let dstReturn = workspace.path("missing-return/dst")
        let dstIgnore = workspace.path("missing-ignore/dst")

        let abortError = #expect(throws: PlatformError.self) {
            try fileSystem.copyItem(at: src, to: dstAbort, errorStrategy: .abortOnError)
        }
        #expect(abortError?.kind == .notFound)

        let thrownReport = try CopyTests.requireThrownReport {
            try fileSystem.copyItem(at: src, to: dstThrow)
        }
        try CopyTests.expectReport(
            thrownReport,
            srcRoot: src,
            dstRoot: dstThrow,
            errors: [("", .copyContents, .notFound)]
        )

        let returnedReport = fileSystem.copyItem(
            at: src,
            to: dstReturn,
            errorStrategy: .collectAndReturn
        )
        try CopyTests.expectReport(
            returnedReport,
            srcRoot: src,
            dstRoot: dstReturn,
            errors: [("", .copyContents, .notFound)]
        )

        fileSystem.copyItem(at: src, to: dstIgnore, errorStrategy: .ignoreAll)

        for dst in [dstAbort, dstThrow, dstReturn, dstIgnore] {
            try Support.expectItemNotExistNoFollow(at: dst)
        }

    }


    @Test
    func `Existing-target error returns a report instead of throwing`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "src file")
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "keep.txt": .file(contents: "dst keep")
            ]
        )
        let dstSnapshot = try Support.TreeSnapshot.capture(at: dst)

        let report = fileSystem.copyItem(
            at: src,
            to: dst,
            options: .init(existingTarget: .error),
            errorStrategy: .collectAndReturn
        )

        try CopyTests.expectReport(report, srcRoot: src, dstRoot: dst, errors: [("", .copyContents, .alreadyExists)])
        try Support.expectTree(at: dst, matches: dstSnapshot, using: .unchanged)

    }

}
