import SystemPackage

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

    }

}
