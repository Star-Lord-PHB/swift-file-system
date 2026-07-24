import Foundation
import SystemPackage
import Testing

/// A recursive filesystem snapshot keyed by paths relative to its root.
extension FileSystemTestSupport {

    struct TreeSnapshot: Equatable, Sendable {

        let root: ItemSnapshot
        let descendants: [FilePath: ItemSnapshot]

        subscript(relativePath: FilePath) -> ItemSnapshot? {
            descendants[relativePath]
        }

        static func capture(
            at rootPath: FilePath,
            capturePayload: Bool = true,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws -> TreeSnapshot {
            var descendants = [FilePath: ItemSnapshot]()
            let root = try captureDirectoryOrItem(
                root: rootPath,
                relativePath: nil,
                capturePayload: capturePayload,
                descendants: &descendants,
                sourceLocation: sourceLocation
            )
            return TreeSnapshot(root: root, descendants: descendants)
        }

        private static func captureDirectoryOrItem(
            root: FilePath,
            relativePath: FilePath?,
            capturePayload: Bool,
            descendants: inout [FilePath: ItemSnapshot],
            sourceLocation: SourceLocation
        ) throws -> ItemSnapshot {

            let absolutePath = relativePath.map { root.appending($0.components) } ?? root

            let initialMetadata = try ItemMetadata.capture(
                at: absolutePath,
                followSymlink: false,
                sourceLocation: sourceLocation
            )

            if initialMetadata.type == .typeDirectory {
                let names = try FileManager.default.contentsOfDirectory(atPath: absolutePath.string)
                for name in names.sorted() {
                    let childRelativePath = relativePath?.appending(name) ?? FilePath(name)
                    let child = try captureDirectoryOrItem(
                        root: root,
                        relativePath: childRelativePath,
                        capturePayload: capturePayload,
                        descendants: &descendants,
                        sourceLocation: sourceLocation
                    )
                    descendants[childRelativePath] = child
                }
            }

            // Directory enumeration can update access metadata, so capture the
            // directory itself only after its children have been observed.
            return try ItemSnapshot.capture(
                at: absolutePath,
                capturePayload: capturePayload,
                sourceLocation: sourceLocation
            )

        }

    }

}
