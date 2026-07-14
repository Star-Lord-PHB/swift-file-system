import Foundation
import SystemPackage

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
        let info: FileInfo
        let payload: Payload
        let posixPermissions: FilePermissions?
        let owner: PlatformIdentity
        let group: PlatformIdentity

        static func capture(
            at path: FilePath,
            followSymlink: Bool = false,
            capturePayload: Bool = true
        ) throws -> ItemSnapshot {
            let initialInfo = try FileInfo(fileAt: path, followSymLink: followSymlink)

            // Read content before taking the final metadata sample. This makes the
            // captured access time describe the state after snapshot observation.
            let payload: Payload
            if capturePayload {
                switch initialInfo.type {
                case .regular:
                    payload = .file(try Data(contentsOf: URL(filePath: path.string)))

                case .symlink:
                    let target = try FileManager.default.destinationOfSymbolicLink(atPath: path.string)
                    payload = .symlinkTarget(FilePath(target))

                default:
                    payload = .none
                }
            } else {
                payload = .notCaptured
            }

            let info = try FileInfo(fileAt: path, followSymLink: followSymlink)
            let (owner, group) = try FileSystem().getOwner(
                forItemAt: path,
                followSymlink: followSymlink
            )

            #if canImport(WinSDK)
                let posixPermissions: FilePermissions? = nil
            #else
                let permissionPath = followSymlink
                    ? URL(filePath: path.string).resolvingSymlinksInPath().path
                    : path.string
                let attributes = try FileManager.default.attributesOfItem(
                    atPath: permissionPath
                )
                guard let rawPermissions = attributes[.posixPermissions] as? NSNumber else {
                    throw CocoaError(.fileReadUnknown)
                }
                let posixPermissions = FilePermissions(
                    rawValue: CModeT(rawPermissions.uint16Value)
                )
            #endif

            return ItemSnapshot(
                path: path,
                followsSymlink: followSymlink,
                info: info,
                payload: payload,
                posixPermissions: posixPermissions,
                owner: owner,
                group: group
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

        static func file(_ contents: String) -> Payload {
            .file(Data(contents.utf8))
        }

    }

}
