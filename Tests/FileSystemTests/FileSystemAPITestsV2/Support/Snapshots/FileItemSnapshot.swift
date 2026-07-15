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
        let followsSymlink: Bool
        let metadata: ItemMetadata
        let payload: Payload
        let posixPermissions: FilePermissions?
        let attributes: PlatformFileAttributes
        let fileIdentifier: FileIdentifier
        let owner: PlatformIdentity
        let group: PlatformIdentity

        static func capture(
            at path: FilePath,
            followSymlink: Bool = false,
            capturePayload: Bool = true
        ) throws -> ItemSnapshot {
            let initialMetadata = try ItemMetadata.capture(
                at: path,
                followSymlink: followSymlink
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
                followSymlink: followSymlink
            )
            let fileInfo = try FileInfo(
                fileAt: path,
                followSymLink: followSymlink
            )
            let (owner, group) = try FileSystem().getOwner(
                forItemAt: path,
                followSymlink: followSymlink
            )

            let posixPermissions = try capturePosixPermissions(
                at: path,
                followSymlink: followSymlink
            )

            return .init(
                path: path,
                followsSymlink: followSymlink,
                metadata: metadata,
                payload: payload,
                posixPermissions: posixPermissions,
                attributes: fileInfo.attributes,
                fileIdentifier: fileInfo.fileIdentifier,
                owner: owner,
                group: group
            )
        }


        static func capturePosixPermissions(
            at path: FilePath,
            followSymlink: Bool
        ) throws -> FilePermissions? {
            #if canImport(WinSDK)
                nil
            #else
                let resolvedPath = followSymlink
                    ? URL(filePath: path.string).resolvingSymlinksInPath().path(percentEncoded: false)
                    : path.string
                let fileManagerAttributes = try FileManager.default.attributesOfItem(
                    atPath: resolvedPath
                )
                let rawPermissions = try #require(
                    fileManagerAttributes[.posixPermissions] as? NSNumber
                ).uint16Value
                return FilePermissions(rawValue: CModeT(rawPermissions))
            #endif
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
