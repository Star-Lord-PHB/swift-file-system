import Foundation
import SystemPackage
import Testing



/// Foundation-observed metadata for one filesystem item.
///
/// This type contains only metadata that Foundation can observe reliably enough
/// to provide an independent assertion path for `FileInfo` APIs.
extension FileSystemTestSupport {

    struct ItemMetadata: Equatable, Sendable {

        let type: FileAttributeType
        let size: UInt64
        let times: Times


        static func capture(
            at path: FilePath,
            followSymlink: Bool = true
        ) throws -> ItemMetadata {
            let url = followSymlink
                ? URL(filePath: path.string).resolvingSymlinksInPath()
                : URL(filePath: path.string)
            let fileManagerAttributes = try FileManager.default.attributesOfItem(
                atPath: url.path
            )
            let resourceValues = try url.resourceValues(forKeys: resourceKeys)

            let foundationType = try #require(fileManagerAttributes[.type] as? FileAttributeType)
            let size = try #require(fileManagerAttributes[.size] as? NSNumber)

            return .init(
                type: foundationType,
                size: size.uint64Value,
                times: Times(
                    access: resourceValues.contentAccessDate,
                    modification: resourceValues.contentModificationDate
                        ?? fileManagerAttributes[.modificationDate] as? Date,
                    statusChange: resourceValues.attributeModificationDate,
                    creation: resourceValues.creationDate
                )
            )
        }


        private static let resourceKeys: Set<URLResourceKey> = [
            .contentAccessDateKey,
            .contentModificationDateKey,
            .attributeModificationDateKey,
            .creationDateKey,
        ]

    }

}



extension FileSystemTestSupport.ItemMetadata {

    struct Times: Equatable, Sendable {

        let access: Date?
        let modification: Date?
        let statusChange: Date?
        let creation: Date?

    }

}
