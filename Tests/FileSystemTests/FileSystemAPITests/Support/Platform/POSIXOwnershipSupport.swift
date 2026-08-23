#if !canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileSystemTestSupport {

    private static let rootGroupIDs: [UInt32] = {
        setgrent()
        defer { endgrent() }

        var groupIDs = [UInt32]()
        while let group = getgrent() {
            groupIDs.append(UInt32(group.pointee.gr_gid))
        }
        return groupIDs
    }()


    static func replacementGroup(
        excluding excludedGroup: UInt32,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> PlatformIdentity? {
        if geteuid() == 0 {
            return rootGroupIDs
                .first(where: { $0 != excludedGroup })
                .map { .init(rawId: $0, platformKind: .group) }
        }

        let groupCount = getgroups(0, nil)
        try #require(groupCount >= 0, sourceLocation: sourceLocation)

        var groups = [gid_t](
            repeating: 0,
            count: Int(groupCount)
        )
        let fetchedCount = groups.withUnsafeMutableBufferPointer { buffer in
            getgroups(groupCount, buffer.baseAddress)
        }
        try #require(
            fetchedCount == groupCount,
            sourceLocation: sourceLocation
        )

        return groups
            .first(where: { UInt32($0) != excludedGroup })
            .map { .init(rawId: UInt32($0), platformKind: .group) }
    }

}

#endif
