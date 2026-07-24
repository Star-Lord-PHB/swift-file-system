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
        followSymlink: Bool = false,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try expectItem(
            at: path,
            matches: expected,
            using: policy,
            followSymlink: followSymlink,
            context: nil,
            sourceLocation: sourceLocation
        )
    }

    static func expectItem(
        at path: FilePath,
        matches expectation: ItemExpectation,
        followSymlink: Bool = false,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        try expectItem(
            at: path,
            matches: expectation.snapshot,
            using: expectation.policy,
            followSymlink: followSymlink,
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
            followSymlink: false,
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
                followSymlink: false,
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
        followSymlink: Bool,
        context: String? = nil,
        sourceLocation: SourceLocation
    ) throws {
        let fields = policy.fields
        let pathContext = context ?? "at \(path), matching snapshot from \(expected.path)"
        let comment = Comment(rawValue: pathContext)

        // Capture times before any other observation in case querying another
        // metadata category changes one of them.
        let times = try ItemMetadata.Times.capture(
            at: path,
            followSymlink: followSymlink,
            sourceLocation: sourceLocation
        )

        // Capture every metadata field before observing payload. Reading regular-
        // file contents may update access time.
        let metadata = try ItemMetadata.capture(
            at: path,
            followSymlink: followSymlink,
            sourceLocation: sourceLocation
        )

        if fields.contains(.type) {
            #expect(metadata.type == expected.metadata.type, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.size), expected.metadata.type != .typeDirectory {
            #expect(metadata.size == expected.metadata.size, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.accessTime) {
            expectTimestampEquals(
                times.access, expected.metadata.times.access,
                comment: comment, sourceLocation: sourceLocation
            )
        }
        if fields.contains(.modificationTime) {
            expectTimestampEquals(
                times.modification, expected.metadata.times.modification,
                comment: comment, sourceLocation: sourceLocation
            )
        }
        if fields.contains(.statusChangeTime) {
            expectTimestampEquals(
                times.statusChange, expected.metadata.times.statusChange,
                comment: comment, sourceLocation: sourceLocation
            )
        }
        if fields.contains(.creationTime) {
            expectTimestampEquals(
                times.creation, expected.metadata.times.creation,
                comment: comment, sourceLocation: sourceLocation
            )
        }
        if fields.contains(.permissions) {
            #expect(
                metadata.security.permissions == expected.metadata.security.permissions,
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.attributes) {
            #expect(
                metadata.attributes.values == expected.metadata.attributes.values,
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.owner) {
            #expect(
                metadata.security.owner == expected.metadata.security.owner,
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.group) {
            #expect(
                metadata.security.group == expected.metadata.security.group,
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.fileIdentifier) {
            #expect(
                metadata.identifier == expected.metadata.identifier,
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

    static func expectTimestampEquals(
        _ lhs: ItemMetadata.Timestamp?,
        _ rhs: ItemMetadata.Timestamp?,
        comment: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(lhs == rhs, comment, sourceLocation: sourceLocation)
    }

}
