import SystemPackage
import Testing

@testable import FileSystemCore

extension FileSystemTestSupport {

    static func expectItem(
        at path: FilePath,
        matches expected: ItemSnapshot,
        using policy: ItemComparisonPolicy,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let actual = try ItemSnapshot.capture(
            at: path,
            followSymlink: expected.followsSymlink,
            capturePayload: policy.fields.contains(.payload)
        )
        expectItemSnapshot(
            actual,
            matches: expected,
            using: policy,
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
        let capturesPayload =
            expectation.root.policy.fields.contains(.payload)
            || expectation.descendants.values.contains { $0.policy.fields.contains(.payload) }
        let actual = try TreeSnapshot.capture(
            at: path,
            capturePayload: capturesPayload
        )

        expectItemSnapshot(
            actual.root,
            matches: expectation.root.snapshot,
            using: expectation.root.policy,
            sourceLocation: sourceLocation
        )

        let expectedPaths = Set(expectation.descendants.keys)
        let actualPaths = Set(actual.descendants.keys)
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

        for relativePath in expectedPaths.intersection(actualPaths).sorted(by: { $0.string < $1.string }) {
            let actualItem = actual.descendants[relativePath]!
            let expectedItem = expectation.descendants[relativePath]!
            expectItemSnapshot(
                actualItem,
                matches: expectedItem.snapshot,
                using: expectedItem.policy,
                context: "at relative path \(relativePath)",
                sourceLocation: sourceLocation
            )
        }
    }

    private static func expectItemSnapshot(
        _ actual: ItemSnapshot,
        matches expected: ItemSnapshot,
        using policy: ItemComparisonPolicy,
        context: String? = nil,
        sourceLocation: SourceLocation
    ) {
        let fields = policy.fields
        let pathContext = context ?? "at \(actual.path), matching snapshot from \(expected.path)"
        let comment = Comment(rawValue: pathContext)

        if fields.contains(.type) {
            #expect(actual.info.type == expected.info.type, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.payload) {
            #expect(actual.payload == expected.payload, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.size), expected.info.type != .directory {
            #expect(actual.info.size == expected.info.size, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.accessTime) {
            #expect(
                fileTime(
                    actual.info.times.lastAccess, equals: expected.info.times.lastAccess,
                    toleranceNanoseconds: policy.timeToleranceNanoseconds),
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.modificationTime) {
            #expect(
                fileTime(
                    actual.info.times.lastModification, equals: expected.info.times.lastModification,
                    toleranceNanoseconds: policy.timeToleranceNanoseconds),
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.statusChangeTime) {
            #expect(
                fileTime(
                    actual.info.times.lastChange, equals: expected.info.times.lastChange,
                    toleranceNanoseconds: policy.timeToleranceNanoseconds),
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.creationTime) {
            #expect(
                optionalFileTime(
                    actual.info.times.creation, equals: expected.info.times.creation,
                    toleranceNanoseconds: policy.timeToleranceNanoseconds),
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.posixPermissions) {
            #expect(actual.posixPermissions == expected.posixPermissions, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.attributes) {
            #expect(actual.info.attributes == expected.info.attributes, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.supportedAttributes) {
            #expect(
                actual.info.supportedAttributes == expected.info.supportedAttributes,
                comment,
                sourceLocation: sourceLocation
            )
        }
        if fields.contains(.owner) {
            #expect(actual.owner == expected.owner, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.group) {
            #expect(actual.group == expected.group, comment, sourceLocation: sourceLocation)
        }
        if fields.contains(.fileIdentifier) {
            #expect(
                actual.info.fileIdentifier == expected.info.fileIdentifier,
                comment,
                sourceLocation: sourceLocation
            )
        }
    }

    private static func optionalFileTime(
        _ lhs: FileTimeSpec?,
        equals rhs: FileTimeSpec?,
        toleranceNanoseconds: Int
    ) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            true
        case (.some(let lhs), .some(let rhs)):
            fileTime(lhs, equals: rhs, toleranceNanoseconds: toleranceNanoseconds)
        default:
            false
        }
    }

    private static func fileTime(
        _ lhs: FileTimeSpec,
        equals rhs: FileTimeSpec,
        toleranceNanoseconds: Int
    ) -> Bool {
        let secondsDelta = Double(lhs.seconds) - Double(rhs.seconds)
        let nanosecondsDelta = Double(lhs.nanoseconds) - Double(rhs.nanoseconds)
        let totalDelta = abs(secondsDelta * 1_000_000_000 + nanosecondsDelta)
        return totalDelta <= Double(toleranceNanoseconds)
    }

}
