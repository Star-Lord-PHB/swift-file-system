import SystemPackage

/// Selects the observable properties that define equality for one test.
extension FileSystemTestSupport {

    struct ItemComparisonPolicy: Sendable {

        var fields: ComparisonFields
        var timeToleranceNanoseconds: Int

        init(
            fields: ComparisonFields,
            timeToleranceNanoseconds: Int = 0
        ) {
            precondition(timeToleranceNanoseconds >= 0)
            self.fields = fields
            self.timeToleranceNanoseconds = timeToleranceNanoseconds
        }

        /// Type and logical content only; suitable for tests that do not promise
        /// metadata preservation.
        static let logicalContents = Self(fields: .logicalContents)

        /// Stable state expected to survive a no-op or failed operation.
        ///
        /// Access time is intentionally omitted because observing file contents can
        /// itself update it. Status-change time is omitted because metadata syscalls
        /// may update it even when other state is preserved.
        static var unchanged: Self {
            let fields: ComparisonFields = [
                .logicalContents,
                .modificationTime,
                .creationTime,
                .posixPermissions,
                .attributes,
                .supportedAttributes,
                .ownership,
                .fileIdentifier,
            ]
            return Self(fields: fields)
        }

        /// State that the recursive copy implementation promises to preserve.
        /// File identity and status-change time must differ for a copy and therefore
        /// are not included. Access time is tested separately with payload capture
        /// disabled, because reading file contents may itself update access time.
        static var copiedItem: Self {
            var fields: ComparisonFields = [
                .logicalContents,
                .modificationTime,
                .creationTime,
                .attributes,
                .ownership,
            ]
            if PlatformCapabilities.supportsPosixPermissions {
                fields.insert(.posixPermissions)
            }
            return Self(fields: fields)
        }

        /// State expected after a same-filesystem move.
        static var movedItem: Self {
            var policy = unchanged
            policy.fields.insert(.fileIdentifier)
            return policy
        }

        /// Logical content and identity expected for hard links.
        static let hardLinkedItem = Self(fields: [.logicalContents, .fileIdentifier])

        /// Every fact represented by `ItemSnapshot`. For regular files, callers
        /// should normally avoid combining payload and access-time comparison in one
        /// assertion because observing payload can update access time.
        static let allObservable = Self(fields: .all)

    }

}

extension FileSystemTestSupport.ItemComparisonPolicy {

    struct ComparisonFields: OptionSet, Sendable {

        let rawValue: UInt64

        static let type = Self(rawValue: 1 << 0)
        static let payload = Self(rawValue: 1 << 1)
        static let size = Self(rawValue: 1 << 2)
        static let accessTime = Self(rawValue: 1 << 3)
        static let modificationTime = Self(rawValue: 1 << 4)
        static let statusChangeTime = Self(rawValue: 1 << 5)
        static let creationTime = Self(rawValue: 1 << 6)
        static let posixPermissions = Self(rawValue: 1 << 7)
        static let attributes = Self(rawValue: 1 << 8)
        static let supportedAttributes = Self(rawValue: 1 << 9)
        static let owner = Self(rawValue: 1 << 10)
        static let group = Self(rawValue: 1 << 11)
        static let fileIdentifier = Self(rawValue: 1 << 12)

        static let logicalContents: Self = [.type, .payload, .size]
        static let fileTimes: Self = [
            .accessTime,
            .modificationTime,
            .statusChangeTime,
            .creationTime,
        ]
        static let ownership: Self = [.owner, .group]
        static let all: Self = [
            .logicalContents,
            .fileTimes,
            .posixPermissions,
            .attributes,
            .supportedAttributes,
            .ownership,
            .fileIdentifier,
        ]

    }

}
