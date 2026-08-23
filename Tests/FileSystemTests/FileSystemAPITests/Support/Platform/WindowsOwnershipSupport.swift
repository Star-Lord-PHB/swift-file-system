#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileSystemTestSupport {

    static func replacementOwner(
        excluding excludedOwner: WindowsSid,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> PlatformIdentity? {
        let token = try currentTokenIdentities(sourceLocation: sourceLocation)

        if token.user != excludedOwner {
            return PlatformIdentity(rawId: token.user, platformKind: .user)
        }

        return token.groups
            .first(where: { group in
                group.sid != excludedOwner
                    && group.attributes & DWORD(SE_GROUP_ENABLED) != 0
                    && group.attributes & DWORD(SE_GROUP_OWNER) != 0
                    && group.attributes & DWORD(SE_GROUP_USE_FOR_DENY_ONLY) == 0
            })
            .map { .init(rawId: $0.sid, platformKind: .group) }
    }


    static func replacementGroup(
        excluding excludedGroup: WindowsSid,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> PlatformIdentity? {
        let token = try currentTokenIdentities(sourceLocation: sourceLocation)
        return token.groups
            .first(where: { group in
                group.sid != excludedGroup
                    && group.attributes & DWORD(SE_GROUP_ENABLED) != 0
                    && group.attributes & DWORD(SE_GROUP_USE_FOR_DENY_ONLY) == 0
            })
            .map { .init(rawId: $0.sid, platformKind: .group) }
    }


    static func currentUserIdentity(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> PlatformIdentity {
        .init(
            rawId: try currentTokenIdentities(sourceLocation: sourceLocation).user,
            platformKind: .user
        )
    }

}



extension FileSystemTestSupport {

    private struct TokenGroup {

        let sid: WindowsSid
        let attributes: DWORD

    }


    private struct TokenIdentities {

        let user: WindowsSid
        let groups: [TokenGroup]

    }


    static func copyWindowsSid(
        _ sid: PSID,
        sourceLocation: SourceLocation
    ) throws -> WindowsSid {
        try #require(IsValidSid(sid), sourceLocation: sourceLocation)

        let byteCount = GetLengthSid(sid)
        let copiedSid = UnsafeMutableRawPointer.allocate(
            byteCount: Int(byteCount),
            alignment: MemoryLayout<SID>.alignment
        )
        let copied = CopySid(byteCount, copiedSid, sid)
        if !copied {
            copiedSid.deallocate()
        }
        try #require(copied, sourceLocation: sourceLocation)

        return WindowsSid(
            unsafeOwningPSid: copiedSid,
            freeingFunc: { $0.deallocate() }
        )
    }


    private static func withTokenInformation<Result>(
        token: HANDLE,
        informationClass: TOKEN_INFORMATION_CLASS,
        sourceLocation: SourceLocation,
        _ body: (UnsafeMutableRawPointer) throws -> Result
    ) throws -> Result {
        var byteCount = DWORD(0)
        let initialResult = GetTokenInformation(
            token,
            informationClass,
            nil,
            0,
            &byteCount
        )
        try #require(!initialResult, sourceLocation: sourceLocation)
        try #require(
            GetLastError() == ERROR_INSUFFICIENT_BUFFER,
            sourceLocation: sourceLocation
        )

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(byteCount),
            alignment: MemoryLayout<UInt>.alignment
        )
        defer { buffer.deallocate() }

        try #require(
            GetTokenInformation(
                token,
                informationClass,
                buffer,
                byteCount,
                &byteCount
            ),
            sourceLocation: sourceLocation
        )
        return try body(buffer)
    }


    private static func currentTokenIdentities(
        sourceLocation: SourceLocation
    ) throws -> TokenIdentities {
        var optionalToken = nil as HANDLE?
        try #require(
            OpenProcessToken(
                GetCurrentProcess(),
                DWORD(TOKEN_QUERY),
                &optionalToken
            ),
            sourceLocation: sourceLocation
        )
        let token = try #require(optionalToken, sourceLocation: sourceLocation)
        defer { CloseHandle(token) }

        let user = try withTokenInformation(
            token: token,
            informationClass: TokenUser,
            sourceLocation: sourceLocation
        ) { buffer in
            let tokenUser = buffer.assumingMemoryBound(to: TOKEN_USER.self)
            return try copyWindowsSid(
                tokenUser.pointee.User.Sid,
                sourceLocation: sourceLocation
            )
        }

        let groups = try withTokenInformation(
            token: token,
            informationClass: TokenGroups,
            sourceLocation: sourceLocation
        ) { buffer in
            let tokenGroups = buffer.assumingMemoryBound(to: TOKEN_GROUPS.self)
            let groupCount = Int(tokenGroups.pointee.GroupCount)
            let groupsOffset = try #require(
                MemoryLayout<TOKEN_GROUPS>.offset(of: \TOKEN_GROUPS.Groups),
                sourceLocation: sourceLocation
            )
            let firstGroup = buffer
                .advanced(by: groupsOffset)
                .assumingMemoryBound(to: SID_AND_ATTRIBUTES.self)

            var groups = [TokenGroup]()
            groups.reserveCapacity(groupCount)
            for index in 0 ..< groupCount {
                let group = firstGroup.advanced(by: index).pointee
                groups.append(
                    TokenGroup(
                        sid: try copyWindowsSid(
                            group.Sid,
                            sourceLocation: sourceLocation
                        ),
                        attributes: group.Attributes
                    )
                )
            }
            return groups
        }

        return TokenIdentities(user: user, groups: groups)
    }

}

#endif
