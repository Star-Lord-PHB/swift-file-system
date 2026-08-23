import SystemPackage

/// Selects the observable properties that define equality for one test.
extension FileSystemTestSupport {

    struct ItemComparisonPolicy: Sendable {

        var fields: ComparisonFields

        init(fields: ComparisonFields) {
            self.fields = fields
        }

        /// Type and logical content only; suitable for tests that do not promise
        /// metadata preservation.
        static let logicalContents: Self = .init(fields: .logicalContents)

        /// Stable state expected to survive a no-op or failed operation.
        ///
        /// Expectations sample metadata before payload, so observing contents does
        /// not hide an access-time change made by the operation under test.
        static var unchanged: Self { .init(fields: .all) }

        /// State that the recursive copy implementation promises to preserve.
        /// File identity and status-change time must differ for a newly copied item
        /// and therefore are not included.
        ///
        /// Access time is only comparable when the snapshot is captured immediately
        /// before the copy with no source reads in between: snapshots record times
        /// after their own payload reads, the copy caches every item's times before
        /// reading its content, and expectations check times before payloads.
        ///
        /// Creation time is excluded on Linux, where the copy cannot write it back.
        /// On Darwin and FreeBSD it is written by lowering the destination's birth
        /// time, which only works downwards: when an overwrite merge reuses an
        /// existing directory whose birth time predates the source's, the
        /// destination keeps its own value — compare such items with
        /// `excluding(.creationTime)`.
        static var copiedItem: Self {
            var fields: ComparisonFields = [
                .logicalContents,
                .accessTime,
                .modificationTime,
                .creationTime,
                .attributes,
                .permissions,
                .ownership,
            ]
            #if canImport(Glibc) || canImport(Musl)
            fields.subtract(.creationTime)
            #endif
            return .init(fields: fields)
        }

        /// State expected after a same-filesystem move.
        ///
        /// A move rewrites the item's directory entry, which advances the status-change
        /// time (POSIX ctime, Windows ChangeTime) on every platform. Everything else,
        /// including the file identifier, is preserved.
        static var movedItem: Self { unchanged.excluding(.statusChangeTime) }

        /// Logical content and identity expected for hard links.
        static let hardLinkedItem: Self = .init(fields: [.logicalContents, .fileIdentifier])

        /// Every fact represented by `ItemSnapshot`.
        static let allObservable: Self = .init(fields: .all)

        /// This policy without the given fields, for per-item carve-outs.
        func excluding(_ excluded: ComparisonFields) -> Self {
            .init(fields: fields.subtracting(excluded))
        }

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
        static let permissions = Self(rawValue: 1 << 7)
        static let attributes = Self(rawValue: 1 << 8)
        static let owner = Self(rawValue: 1 << 9)
        static let group = Self(rawValue: 1 << 10)
        static let fileIdentifier = Self(rawValue: 1 << 11)

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
            .permissions,
            .attributes,
            .ownership,
            .fileIdentifier,
        ]

    }

}
