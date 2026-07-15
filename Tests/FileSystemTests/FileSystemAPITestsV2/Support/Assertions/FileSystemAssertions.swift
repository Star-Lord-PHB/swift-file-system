import Foundation
import SystemPackage
import Testing

import SwiftFileSystem


extension FileSystemTestSupport {

    static func expectItemExistNoFollow(at path: FilePath, sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(try itemExistsNoFollow(at: path), "Expected item to exist at \(path)", sourceLocation: sourceLocation)
    }

    static func expectItemNotExistNoFollow(at path: FilePath, sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(try !itemExistsNoFollow(at: path), "Expected item to not exist at \(path)", sourceLocation: sourceLocation)
    }

    static func expectItem(
        at path: FilePath,
        matches expected: ItemSnapshot,
        using policy: ItemComparisonPolicy,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try expectItem(
            at: path,
            matches: expected,
            using: policy,
            context: nil,
            sourceLocation: sourceLocation
        )
    }

    static func expectItem(
        at path: FilePath,
        matches expectation: ItemExpectation,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try expectItem(
            at: path,
            matches: expectation.snapshot,
            using: expectation.policy,
            sourceLocation: sourceLocation
        )
    }

    static func expectTree(
        at path: FilePath,
        matches expected: TreeSnapshot,
        using policy: ItemComparisonPolicy,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try expectTree(
            at: path,
            matches: TreeExpectation(matching: expected, using: policy),
            sourceLocation: sourceLocation
        )
    }

    static func expectTree(
        at path: FilePath,
        matches expectation: TreeExpectation,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try expectItem(
            at: path,
            matches: expectation.root.snapshot,
            using: expectation.root.policy,
            context: "at tree root \(path)",
            sourceLocation: sourceLocation
        )

        for (relativePath, expectedItem) in expectation.descendants {

            let actualPath = path.appending(relativePath.components)

            guard try itemExistsNoFollow(at: actualPath) else { continue }

            try expectItem(
                at: actualPath,
                matches: expectedItem.snapshot,
                using: expectedItem.policy,
                context: "at relative path \(relativePath)",
                sourceLocation: sourceLocation
            )

        }

        // Enumerating directories can update access metadata. Do it only after
        // every expected item has had its metadata and payload checked.
        let expectedPaths = Set(expectation.descendants.keys)
        let actualPaths = try descendantPaths(at: path)
        let missingPaths = expectedPaths.subtracting(actualPaths).sorted { $0.string < $1.string }
        let unexpectedPaths = actualPaths.subtracting(expectedPaths).sorted { $0.string < $1.string }

        #expect(
            missingPaths.isEmpty,
            "Missing filesystem entries: \(missingPaths.map(\.string))",
            sourceLocation: sourceLocation
        )
        #expect(
            unexpectedPaths.isEmpty,
            "Unexpected filesystem entries: \(unexpectedPaths.map(\.string))",
            sourceLocation: sourceLocation
        )
    }

    private static func expectItem(
        at path: FilePath,
        matches expected: ItemSnapshot,
        using policy: ItemComparisonPolicy,
        context: String? = nil,
        sourceLocation: SourceLocation
    ) throws {
        let fields = policy.fields
        let pathContext = context ?? "at \(path), matching snapshot from \(expected.path)"
        let comment = Comment(rawValue: pathContext)

        // Capture every requested metadata field before observing payload. Reading
        // regular-file contents may update access time.
        let metadata = try ItemMetadata.capture(
            at: path,
            followSymlink: expected.followsSymlink
        )
        let fileInfo = fields.contains(.attributes) || fields.contains(.fileIdentifier)
            ? try FileInfo(fileAt: path, followSymLink: expected.followsSymlink)
            : nil
        let ownership = fields.contains(.owner) || fields.contains(.group)
            ? try FileSystem().getOwner(forItemAt: path, followSymlink: expected.followsSymlink)
            : nil

        if fields.contains(.type) {
            #expect(metadata.type == expected.metadata.type, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.size), expected.metadata.type != .typeDirectory {
            #expect(metadata.size == expected.metadata.size, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.accessTime) {
            expectDateEquals(
                metadata.times.access, expected.metadata.times.access,
                toleranceNanoseconds: policy.timeToleranceNanoseconds,
                comment: comment, sourceLocation: sourceLocation
            )
        }
        if fields.contains(.modificationTime) {
            expectDateEquals(
                metadata.times.modification, expected.metadata.times.modification,
                toleranceNanoseconds: policy.timeToleranceNanoseconds,
                comment: comment, sourceLocation: sourceLocation
            )
        }
        if fields.contains(.statusChangeTime) {
            expectDateEquals(
                metadata.times.statusChange, expected.metadata.times.statusChange,
                toleranceNanoseconds: policy.timeToleranceNanoseconds,
                comment: comment, sourceLocation: sourceLocation
            )
        }
        if fields.contains(.creationTime) {
            expectDateEquals(
                metadata.times.creation, expected.metadata.times.creation,
                toleranceNanoseconds: policy.timeToleranceNanoseconds,
                comment: comment, sourceLocation: sourceLocation
            )
        }
        if fields.contains(.posixPermissions) {
            let posixPermissions = try ItemSnapshot.capturePosixPermissions(at: path, followSymlink: expected.followsSymlink)
            #expect(posixPermissions == expected.posixPermissions, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.attributes) {
            #expect(fileInfo!.attributes == expected.attributes, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.owner) {
            #expect(ownership!.owner == expected.owner, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.group) {
            #expect(ownership!.group == expected.group, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.fileIdentifier) {
            #expect(
                fileInfo!.fileIdentifier == expected.fileIdentifier,
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.payload) {
            let payload = try ItemSnapshot.Payload.capture(
                at: path,
                type: metadata.type
            )
            #expect(payload == expected.payload, comment, sourceLocation: sourceLocation)
        }
    }

    private static func descendantPaths(
        at rootPath: FilePath
    ) throws -> Set<FilePath> {
        var paths = Set<FilePath>()
        try collectDescendantPaths(
            root: rootPath,
            relativePath: nil,
            into: &paths
        )
        return paths
    }

    private static func collectDescendantPaths(
        root: FilePath,
        relativePath: FilePath?,
        into paths: inout Set<FilePath>
    ) throws {
        let absolutePath = relativePath.map { root.appending($0.components) } ?? root
        let attributes = try FileManager.default.attributesOfItem(
            atPath: absolutePath.string
        )
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            return
        }

        let names = try FileManager.default.contentsOfDirectory(
            atPath: absolutePath.string
        )
        for name in names {
            let childRelativePath = relativePath?.appending(name) ?? FilePath(name)
            paths.insert(childRelativePath)
            try collectDescendantPaths(
                root: root,
                relativePath: childRelativePath,
                into: &paths
            )
        }
    }

    static func itemExistsNoFollow(at path: FilePath) throws -> Bool {
        do {
            _ = try FileManager.default.attributesOfItem(atPath: path.string)
            return true
        } catch let error as CocoaError 
        where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return false
        }
    }

    private static func expectDateEquals(
        _ lhs: Date?, _ rhs: Date?, toleranceNanoseconds: Int,
        comment: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        switch (lhs, rhs) {
        case (.some(let lhs), .some(let rhs)):
            let delta = abs(lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate)
            #expect(delta <= Double(toleranceNanoseconds) / 1_000_000_000, comment, sourceLocation: sourceLocation)
        default:
            #expect(lhs == rhs, comment, sourceLocation: sourceLocation)
        }
    }

}
