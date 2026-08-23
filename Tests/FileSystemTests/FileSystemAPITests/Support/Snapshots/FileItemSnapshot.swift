import Foundation
import SystemPackage
import Testing

@testable import FileSystemCore
@testable import SwiftFileSystem

/// The observed state of one filesystem item.
///
/// A snapshot contains facts only. Which facts matter to a test is determined
/// separately by `ItemComparisonPolicy`.
extension FileSystemTestSupport {

    struct ItemSnapshot: Equatable, Sendable {

        let path: FilePath
        let metadata: ItemMetadata
        let payload: Payload

        static func capture(
            at path: FilePath,
            followSymlink: Bool = false,
            capturePayload: Bool = true,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws -> ItemSnapshot {
            let initialMetadata = try ItemMetadata.capture(
                at: path,
                followSymlink: followSymlink,
                sourceLocation: sourceLocation
            )

            // Read content before taking the final metadata sample. This makes the
            // captured access time describe the state after snapshot observation.
            let payload: Payload = if capturePayload {
                try Payload.capture(at: path, type: initialMetadata.type)
            } else {
                .notCaptured
            }

            let metadata = try ItemMetadata.capture(
                at: path,
                followSymlink: followSymlink,
                sourceLocation: sourceLocation
            )

            return .init(
                path: path,
                metadata: metadata,
                payload: payload
            )
        }

    }

}



extension FileSystemTestSupport.ItemSnapshot {

    enum Payload: Equatable, Sendable {

        case file(Data)
        case symlinkTarget(FilePath)
        case notCaptured
        case none


        static func capture(
            at path: FilePath,
            type: FileAttributeType
        ) throws -> Payload {
            switch type {
            case .typeRegular:
                .file(try Data(contentsOf: URL(filePath: path.string)))

            case .typeSymbolicLink:
                .symlinkTarget(
                    .init(
                        try FileManager.default.destinationOfSymbolicLink(
                            atPath: path.string
                        )
                    )
                )

            default:
                .none
            }
        }


        static func file(_ contents: String) -> Payload {
            .file(Data(contents.utf8))
        }

    }

}
