import SystemPackage
import Testing

extension FileSystemTestSupport {

    struct ItemExpectation: Sendable {

        var snapshot: ItemSnapshot
        var policy: ItemComparisonPolicy

        init(
            matching snapshot: ItemSnapshot,
            using policy: ItemComparisonPolicy
        ) {
            self.snapshot = snapshot
            self.policy = policy
        }

    }

    /// An exact expected tree. Every listed relative path must exist and no other
    /// descendants are allowed.
    struct TreeExpectation: Sendable {

        var root: ItemExpectation
        var descendants: [FilePath: ItemExpectation]

        init(
            matching snapshot: TreeSnapshot,
            using policy: ItemComparisonPolicy
        ) {
            root = ItemExpectation(matching: snapshot.root, using: policy)
            descendants = snapshot.descendants.mapValues {
                ItemExpectation(matching: $0, using: policy)
            }
        }

        mutating func expectRoot(
            matching snapshot: ItemSnapshot,
            using policy: ItemComparisonPolicy
        ) {
            root = ItemExpectation(matching: snapshot, using: policy)
        }

        mutating func expectItem(
            at relativePath: FilePath,
            matching snapshot: ItemSnapshot,
            using policy: ItemComparisonPolicy
        ) {
            precondition(relativePath.isRelative && !relativePath.isEmpty)
            descendants[relativePath] = ItemExpectation(
                matching: snapshot,
                using: policy
            )
        }

        mutating func removeItem(at relativePath: FilePath) {
            descendants.removeValue(forKey: relativePath)
        }

        /// Replaces the policies of existing entries, keeping their snapshots.
        /// The empty path addresses the root; a path without an entry fails the test.
        mutating func updatePolicies(
            _ policies: [FilePath: ItemComparisonPolicy],
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws {
            for (relativePath, policy) in policies {
                if relativePath.isEmpty {
                    root.policy = policy
                } else {
                    try #require(descendants[relativePath] != nil, sourceLocation: sourceLocation)
                    descendants[relativePath]?.policy = policy
                }
            }
        }

        /// Merges entries taken from another snapshot, replacing any existing entry at the
        /// same path. The empty path addresses the root; a path the snapshot does not
        /// contain fails the test.
        mutating func add(
            from snapshot: TreeSnapshot,
            items: [FilePath: ItemComparisonPolicy],
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws {
            for (relativePath, policy) in items {
                if relativePath.isEmpty {
                    expectRoot(matching: snapshot.root, using: policy)
                } else {
                    let itemSnapshot = try #require(
                        snapshot[relativePath],
                        sourceLocation: sourceLocation
                    )
                    expectItem(at: relativePath, matching: itemSnapshot, using: policy)
                }
            }
        }

    }

}
