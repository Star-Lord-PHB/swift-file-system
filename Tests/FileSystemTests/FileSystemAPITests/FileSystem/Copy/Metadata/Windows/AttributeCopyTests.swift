#if canImport(WinSDK)

import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    @Suite("Windows attributes")
    struct AttributeCopyTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The sparse flag and the allocated size are not preserved by `CopyFileEx` and are
// deliberately not asserted. ADS preservation is untested for the same reason as Darwin
// xattr: the library exposes no API for it, so it is not a public guarantee.
extension FileSystemAPITests.CopyTests.AttributeCopyTests {

    private func setNativeAttributes(
        _ attributes: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let success = path.withPlatformString { pathPointer in
            SetFileAttributesW(pathPointer, attributes.rawValue)
        }
        try #require(success, sourceLocation: sourceLocation)
    }


    /// Adds the attributes to the item's current ones, the usual read-modify-write shape.
    private func addNativeAttributes(
        _ additions: PlatformFileAttributes,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let current = try Support.ItemMetadata.captureAttributes(
            at: path,
            sourceLocation: sourceLocation
        ).values
        try setNativeAttributes(
            current.subtracting(.windows.isNormal).union(additions),
            at: path,
            sourceLocation: sourceLocation
        )
    }


    /// READONLY blocks deletion and would break the workspace cleanup; call from a
    /// `defer` for both sides of a READONLY copy.
    private func clearNativeAttributes(at path: FilePath) {
        _ = path.withPlatformString { pathPointer in
            SetFileAttributesW(pathPointer, PlatformFileAttributes.windows.isNormal.rawValue)
        }
    }


    @Test
    func `Copies file attributes`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        try addNativeAttributes([.windows.isHidden, .windows.isNotContentIndexed], at: src)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        let dst = workspace.path("dst.txt")

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `Copies dir attributes`() throws {

        let src = try workspace.makeFixture(
            at: "src",
            [
                "file.txt": .file(contents: "contents")
            ]
        )
        try addNativeAttributes([.windows.isHidden, .windows.isNotContentIndexed], at: src)
        let srcSnapshot = try Support.TreeSnapshot.capture(at: src)
        let dst = workspace.path("dst")

        try fileSystem.copyItem(at: src, to: dst)

        try Support.expectTree(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `Copies a READONLY file to a new destination`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let dst = workspace.path("dst.txt")
        defer {
            clearNativeAttributes(at: src)
            clearNativeAttributes(at: dst)
        }
        try addNativeAttributes([.windows.isReadOnly], at: src)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst)

        // Ordering sentinel: `CopyFileW` stamps READONLY onto the temporary file right
        // away and READONLY blocks `SetFileTime`, so the copy must write the times
        // before the attributes — a reordering makes this copy fail outright.
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }
    
    
    @Test
    func `Copies a READONLY symlink to a new destination`() throws {
        
        let src = try workspace.makeSymlink(at: "lnk", pointingTo: "missing")
        let dst = workspace.path("dst")
        defer {
            clearNativeAttributes(at: src)
            clearNativeAttributes(at: dst)
        }
        try addNativeAttributes([.windows.isReadOnly], at: src)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        
        try fileSystem.copyItem(at: src, to: dst)
        
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)
        
    }


    @Test
    func `Overwrites an existing destination with a READONLY file`() throws {

        let src = try workspace.makeFile(at: "src.txt", contents: "contents")
        let dst = try workspace.makeFile(at: "dst.txt", contents: "old contents")
        defer {
            clearNativeAttributes(at: src)
            clearNativeAttributes(at: dst)
        }
        try addNativeAttributes([.windows.isReadOnly], at: src)
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)

        try fileSystem.copyItem(at: src, to: dst, options: .init(existingTarget: .overwrite))

        // READONLY on the temporary file does not block the rename onto the existing
        // destination: replacing is decided by the parent directory's permissions.
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


}

#endif
