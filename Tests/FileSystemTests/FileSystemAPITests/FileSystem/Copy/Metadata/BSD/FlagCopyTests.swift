#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("BSD flags")
    struct FlagCopyTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: Darwin xattr and ACL preservation (`fcopyfile` with `COPYFILE_XATTR | COPYFILE_ACL`)
// is deliberately untested: the library exposes no xattr/ACL metadata API, so preserving
// them is an implementation convenience rather than a public guarantee. Add tests once
// such an API exists.
extension FileSystemAPITests.CopyTests.FlagCopyTests {

    private func setNativeFlags(
        _ attributes: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let result = path.withPlatformString { chflags($0, attributes.rawValue) }
        try #require(result == 0, sourceLocation: sourceLocation)
    }


    /// Clears the BSD flags of every item in the tree rooted at `path`, ignoring failures.
    ///
    /// `uchg` blocks the workspace cleanup, so uchg tests call this from a `defer` for
    /// both the source and the destination tree. A uchg directory does not prevent
    /// enumerating it or changing its children's flags, so the order does not matter.
    private func clearBSDFlagsRecursively(at path: FilePath) {
        _ = path.withPlatformString { lchflags($0, 0) }
        let enumerator = FileManager.default.enumerator(atPath: path.string)
        while let relativePath = enumerator?.nextObject() as? String {
            _ = path.appending(relativePath).withPlatformString { lchflags($0, 0) }
        }
    }


    @Test
    func `Copies a uchg file to a new destination`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let dst = workspace.path("dst.txt")
        defer {
            clearBSDFlagsRecursively(at: src)
            clearBSDFlagsRecursively(at: dst)
        }
        try setNativeFlags([.bsd.isUserImmutable], at: src)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        // The flags are written last, after the rename; an immutable destination would
        // otherwise block the remaining metadata writes and the rename itself.
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)
        #expect(
            try Support.ItemMetadata.captureAttributes(at: dst).values.contains(.bsd.isUserImmutable)
        )

    }


    @Test
    func `Overwrites an existing destination with a uchg file`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let dst = try workspace.makeFile(at: "dst.txt", contents: "old contents")
        defer {
            clearBSDFlagsRecursively(at: src)
            clearBSDFlagsRecursively(at: dst)
        }
        try setNativeFlags([.bsd.isUserImmutable], at: src)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `Copies a uchg directory tree completely`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "file contents"),
                "sub": [
                    "nested.txt": .file(contents: "nested contents")
                ],
            ]
        )
        let dst = workspace.path("dst")
        defer {
            clearBSDFlagsRecursively(at: src)
            clearBSDFlagsRecursively(at: dst)
        }
        try setNativeFlags([.bsd.isUserImmutable], at: src.appending("file.txt"))
        try setNativeFlags([.bsd.isUserImmutable], at: src)
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        // The destination directory receives uchg only when it is left, after all of its
        // children have been written into it.
        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)

    }

}

#endif
