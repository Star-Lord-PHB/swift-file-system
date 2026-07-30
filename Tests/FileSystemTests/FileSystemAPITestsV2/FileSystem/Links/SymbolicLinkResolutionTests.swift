import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    @Suite("Symbolic-link resolution")
    struct SymbolicLinkResolutionTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.SymbolicLinkResolutionTests {

    private func expectRecursiveResolution(
        _ path: FilePath,
        matches target: Support.ItemSnapshot,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        #expect(!path.isRelative, sourceLocation: sourceLocation)
        try Support.expectItem(
            at: path,
            matches: target,
            using: .init(fields: [.logicalContents, .fileIdentifier]),
            sourceLocation: sourceLocation
        )
    }


    @Test
    func `Direct resolution returns an absolute destination unchanged`() throws {

        let storedTarget = workspace.path("missing-target")
        let link = try workspace.makeSymlink(
            at: "link",
            pointingTo: storedTarget
        )

        let destination = try fileSystem.destinationOfSymLink(
            at: link,
            recursive: false
        )

        #expect(destination == storedTarget)

    }


    @Test
    func `Direct resolution returns a relative destination without normalization`() throws {

        let storedTarget = "directory/./nested/../missing-target" as FilePath
        let link = try workspace.makeSymlink(
            at: "link",
            pointingTo: storedTarget
        )

        let destination = try fileSystem.destinationOfSymLink(
            at: link,
            recursive: false
        )

        #expect(destination == storedTarget)

    }


    @Test
    func `Default resolution is recursive`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let link = try workspace.makeSymlink(
            at: "link",
            pointingTo: target
        )
        let targetSnapshot = try Support.ItemSnapshot.capture(at: target)

        let resolvedPath = try fileSystem.destinationOfSymLink(at: link)

        try expectRecursiveResolution(resolvedPath, matches: targetSnapshot)

    }


    @Test
    func `Recursive resolution follows links in multiple path components`() throws {

        try workspace.makeFixture(
            at: "fixture",
            [
                "a-link": .symlink(target: "directory-a"),
                "directory-a": [
                    "b-link": .symlink(target: "directory-b"),
                    "directory-b": [
                        "target": .file(contents: "target contents"),
                        "target-link": .symlink(target: "target")
                    ]
                ]
            ]
        )
        let target = workspace.path("fixture/directory-a/directory-b/target")
        let path = workspace.path("fixture/a-link/b-link/target-link")
        let targetSnapshot = try Support.ItemSnapshot.capture(at: target)

        let resolvedPath = try fileSystem.destinationOfSymLink(at: path, recursive: true)

        try expectRecursiveResolution(resolvedPath, matches: targetSnapshot)

    }


    @Test
    func `Recursive resolution fails for a dangling symlink`() throws {

        let link = try workspace.makeSymlink(
            at: "link",
            pointingTo: "missing-target"
        )

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.destinationOfSymLink(at: link, recursive: true)
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `Direct resolution fails for a non-symlink`() throws {

        let path = try workspace.makeFile(at: "file")

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.destinationOfSymLink(at: path, recursive: false)
        }

        #expect(error?.kind == .notASymlink)

    }


    @Test
    func `Recursive resolution fails for a symlink cycle`() throws {

        let first = try workspace.makeSymlink(
            at: "first",
            pointingTo: "second"
        )
        try workspace.makeSymlink(
            at: "second",
            pointingTo: "first"
        )

        let error = #expect(throws: PlatformError.self) {
            try fileSystem.destinationOfSymLink(at: first, recursive: true)
        }

        #expect(error?.kind == .pathResolutionFailed)

    }

}
