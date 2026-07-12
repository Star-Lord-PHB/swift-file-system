import Foundation
import SystemPackage

@testable import FileSystemCore

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
            capturePayload: Bool = true
        ) throws -> TreeSnapshot {
            var descendants = [FilePath: ItemSnapshot]()
            let root = try captureDirectoryOrItem(
                at: rootPath,
                relativePath: nil,
                capturePayload: capturePayload,
                descendants: &descendants
            )
            return TreeSnapshot(root: root, descendants: descendants)
        }

        private static func captureDirectoryOrItem(
            at absolutePath: FilePath,
            relativePath: FilePath?,
            capturePayload: Bool,
            descendants: inout [FilePath: ItemSnapshot]
        ) throws -> ItemSnapshot {
            let initialInfo = try FileInfo(fileAt: absolutePath, followSymLink: false)

            if initialInfo.type == .directory {
                let names = try FileManager.default.contentsOfDirectory(atPath: absolutePath.string)
                for name in names.sorted() {
                    let component = FilePath.Component(name)!
                    let childAbsolutePath = absolutePath.appending(component)
                    let childRelativePath = relativePath?.appending(component) ?? FilePath(name)
                    let child = try captureDirectoryOrItem(
                        at: childAbsolutePath,
                        relativePath: childRelativePath,
                        capturePayload: capturePayload,
                        descendants: &descendants
                    )
                    descendants[childRelativePath] = child
                }
            }

            // Directory enumeration can update access metadata, so capture the
            // directory itself only after its children have been observed.
            return try ItemSnapshot.capture(
                at: absolutePath,
                capturePayload: capturePayload
            )
        }

    }

}
