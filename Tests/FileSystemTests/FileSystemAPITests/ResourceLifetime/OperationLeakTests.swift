import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension ResourceLifetimeTests {

    @Suite("Operations")
    struct OperationLeakTests {

        typealias Support = ResourceLifetimeTests.Support

        typealias LeakChecker = ResourceLifetimeTests.LeakChecker

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }


        var sampleTreeFixture: Support.Fixture {
            [
                "file.txt": .file(contents: "contents"),
                "link": .symlink(target: "file.txt"),
                "sub": [
                    "nested.txt": .file(contents: "nested")
                ],
            ]
        }

    }

}



extension ResourceLifetimeTests.OperationLeakTests {

    @Test
    func `Item creation and removal does not leak resources`() throws {

        let directory = workspace.path("directory")

        try LeakChecker.expectNoLeak {
            try fileSystem.createDirectory(at: directory)
            try fileSystem.createFile(at: directory.appending("file.txt"))
            try fileSystem.createSymLink(at: directory.appending("link"), pointingTo: "file.txt")
            try fileSystem.createHardLink(
                at: directory.appending("hard-link"),
                for: directory.appending("file.txt")
            )
            try fileSystem.removeItem(at: directory)
        }

    }


    @Test
    func `Failed removal does not leak resources`() throws {

        let missing = workspace.path("missing")

        try LeakChecker.expectNoLeak {
            #expect(throws: PlatformError.self) {
                try fileSystem.removeItem(at: missing)
            }
        }

    }


    @Test
    func `Copy does not leak resources`() throws {

        let src = try workspace.makeFixture(at: "src", sampleTreeFixture)
        let dst = workspace.path("dst")

        try LeakChecker.expectNoLeak {
            try fileSystem.copyItem(at: src, to: dst)
            try fileSystem.removeItem(at: dst)
        }

    }


    #if !canImport(WinSDK)
    @Test
    func `Copy collecting unsupported entries does not leak resources`() throws {

        let src = try workspace.makeFixture(at: "src", sampleTreeFixture)
        try #require(mkfifo(src.appending("fifo").string, 0o644) == 0)
        let dst = workspace.path("dst")

        try LeakChecker.expectNoLeak {
            let report = fileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)
            #expect(report != nil)
            try fileSystem.removeItem(at: dst)
        }

    }
    #endif


    #if canImport(WinSDK)
    @Test
    func `Copy collecting unsupported entries does not leak resources`() throws {

        let junctionTarget = try workspace.makeDirectory(at: "junction-target")
        let src = try workspace.makeFixture(at: "src", sampleTreeFixture)
        try Support.makeWindowsJunction(at: src.appending("junction"), pointingTo: junctionTarget)
        let dst = workspace.path("dst")

        try LeakChecker.expectNoLeak {
            let report = fileSystem.copyItem(at: src, to: dst, errorStrategy: .collectAndReturn)
            #expect(report != nil)
            try fileSystem.removeItem(at: dst)
        }

    }
    #endif


    @Test
    func `Aborted copy does not leak resources`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "sub": [
                    "clash": [
                        "child.txt": .file(contents: "src child")
                    ]
                ]
            ]
        )
        let dst = try workspace.makeFixture(
            at: "dst",
            [
                "sub": [
                    "clash": .file(contents: "dst clash")
                ]
            ]
        )

        try LeakChecker.expectNoLeak {
            #expect(throws: PlatformError.self) {
                try fileSystem.copyItem(
                    at: src,
                    to: dst,
                    options: .init(existingTarget: .overwrite),
                    errorStrategy: .abortOnError
                )
            }
        }

    }


    @Test
    func `Move does not leak resources`() throws {

        let file = try workspace.makeFile(at: "file-a.txt", contents: "contents")
        let movedFile = workspace.path("file-b.txt")
        let directory = try workspace.makeDirectory(at: "dir-a")
        let movedDirectory = workspace.path("dir-b")

        try LeakChecker.expectNoLeak {
            try fileSystem.moveItem(at: file, to: movedFile)
            try fileSystem.moveItem(at: movedFile, to: file)
            try fileSystem.moveItem(at: directory, to: movedDirectory)
            try fileSystem.moveItem(at: movedDirectory, to: directory)
        }

    }


    @Test
    func `Failed move does not leak resources`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let existingDst = try workspace.makeFile(at: "existing.txt", contents: "occupied")
        let missing = workspace.path("missing")

        try LeakChecker.expectNoLeak {
            #expect(throws: PlatformError.self) {
                try fileSystem.moveItem(at: missing, to: workspace.path("dst.txt"))
            }
            #expect(throws: PlatformError.self) {
                try fileSystem.moveItem(at: src, to: existingDst, onExistingTarget: .error)
            }
        }

    }

}
