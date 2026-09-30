#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem


extension WindowsAccessCheckerTests {

    /// Value-level tests over constructed security descriptors; no files are involved.
    ///
    /// Expected masks are hand-computed from the DACL contents. Descriptors are built
    /// through the independently tested `WindowsAbsoluteSecurityDescriptor` machinery
    /// with SYSTEM as owner/group (so no owner-implied rights leak into results),
    /// except where a test targets the owner-implied grant itself.
    ///
    /// The evaluated identity is LOCAL SERVICE rather than the current user: its groups
    /// resolve locally everywhere (those of a Windows container's virtual account do not),
    /// and the test process does not hold it, so a granted mask can only come from
    /// evaluating that identity rather than the caller's own token.
    @Suite("Effective access mask")
    struct EffectiveAccessMaskTests {}

}



extension WindowsAccessCheckerTests.EffectiveAccessMaskTests {

    private var fileGenericRead: WindowsAccessMask { .init(rawValue: FILE_GENERIC_READ) }


    private var evaluatedIdentity: PlatformIdentity {
        .init(rawId: .localService, platformKind: .user)
    }


    private var evaluatedTrustee: WindowsExplicitAccess.RawTrustee {
        .init(sid: .localService, type: .user)
    }


    /// Cancels when Authz cannot build a SID-based context for `identity` because it
    /// cannot resolve the identity's groups, as for the virtual account a Windows
    /// container runs under (ERROR_NO_SUCH_DOMAIN).
    private func requireSidBasedEvaluation(
        of identity: PlatformIdentity,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var resourceManager = nil as AUTHZ_RESOURCE_MANAGER_HANDLE?
        try #require(
            AuthzInitializeResourceManager(DWORD(AUTHZ_RM_FLAG_NO_AUDIT), nil, nil, nil, nil, &resourceManager),
            sourceLocation: sourceLocation
        )
        defer { AuthzFreeResourceManager(resourceManager) }

        var context = nil as AUTHZ_CLIENT_CONTEXT_HANDLE?
        if AuthzInitializeContextFromSid(0, identity.rawId.psid.unsafeResourcePtr, resourceManager, nil, LUID(), nil, &context) {
            AuthzFreeContext(context)
            return
        }
        let error = GetLastError()
        try #require(
            error == ERROR_NO_SUCH_DOMAIN,
            "AuthzInitializeContextFromSid failed with \(error)",
            sourceLocation: sourceLocation
        )
        try Test.cancel("Authz cannot resolve the groups of \(identity)", sourceLocation: sourceLocation)
    }


    private func makeSelfRelativeSD(
        owner: WindowsSid = .system,
        dacl: consuming WindowsRawAclState
    ) -> WindowsSelfRelativeSecurityDescriptor {
        WindowsAbsoluteSecurityDescriptor(dacl: dacl, owner: owner, group: .system).makeSelfRelative()
    }


    @Test
    func `Allow entry grants exactly its mask`() throws {

        let identity = evaluatedIdentity
        let permission = [.readData, .readAttributes, .synchronize] as WindowsAccessMask
        let acl = WindowsRawAcl(entries: [
            .init(permission: permission, trustee: .init(sid: identity.rawId, type: .user))
        ])
        let sd = makeSelfRelativeSD(dacl: .acl(acl))

        let granted = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)

        #expect(granted == permission)

    }


    @Test
    func `Deny entry is subtracted from allow grant`() throws {

        let identity = evaluatedIdentity
        let acl = WindowsRawAcl(entries: [
            .init(permission: .readData, accessMode: .denyAccess, trustee: evaluatedTrustee),
            .init(permission: fileGenericRead, trustee: evaluatedTrustee),
        ])
        let sd = makeSelfRelativeSD(dacl: .acl(acl))

        let granted = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)

        #expect(granted == fileGenericRead.subtracting(.readData))

    }


    @Test
    func `Owner is implicitly granted readControl and writeDAC`() throws {

        let identity = evaluatedIdentity
        let sd = makeSelfRelativeSD(owner: identity.rawId, dacl: .acl(WindowsRawAcl(entries: [])))

        let granted = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)

        #expect(granted == [.readControl, .writeDAC])

    }


    @Test
    func `Null DACL grants all standard and specific rights`() throws {

        let identity = evaluatedIdentity
        let sd = makeSelfRelativeSD(dacl: .null)

        let granted = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)

        #expect(granted == .init(rawValue: 0x001F_FFFF))

    }


    @Test
    func `Absent DACL is equivalent to null DACL`() throws {

        // MSDN warns the descriptor must carry DACL information (error 87), but measured
        // behavior is that AuthzAccessCheck treats an absent DACL like a null one:
        // unprotected, full grant. This also pins the three-state design's claim that
        // .absent and .null are equivalent at access-check level.
        let identity = evaluatedIdentity
        let sd = makeSelfRelativeSD(dacl: .absent)

        let granted = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)

        #expect(granted == .init(rawValue: 0x001F_FFFF))

    }


    @Test
    func `Missing owner evaluation fails`() throws {

        let identity = evaluatedIdentity

        let error = #expect(throws: PlatformError.self) {
            let acl = WindowsRawAcl(entries: [
                .init(permission: .readData, trustee: evaluatedTrustee)
            ])
            let sd = WindowsAbsoluteSecurityDescriptor(dacl: .acl(acl)).makeSelfRelative()
            _ = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)
        }

        #expect(error?.systemCode == .invalidParameter)

    }


    @Test
    func `Empty DACL grants nothing`() throws {

        // Empty (present, zero entries) is deny-all, unlike the allow-all null DACL;
        // the result is an empty mask, not an error.
        let identity = evaluatedIdentity
        let sd = makeSelfRelativeSD(dacl: .acl(WindowsRawAcl(entries: [])))

        let granted = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)

        #expect(granted == [])

    }


    @Test
    func `Inherit-only entry is excluded`() throws {

        let identity = evaluatedIdentity
        let acl = WindowsRawAcl(entries: [
            .init(
                permission: .writeData,
                inheritance: [.inheritOnly, .allSubItems],
                trustee: evaluatedTrustee
            ),
            .init(permission: .readData, trustee: evaluatedTrustee),
        ])
        let sd = makeSelfRelativeSD(dacl: .acl(acl))

        let granted = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)

        #expect(granted == .readData)

    }


    @Test
    func `Unmapped generic bits grant nothing`() throws {

        // Generic bits are mapped when inheritable entries are instantiated, never at
        // check time; a non-inherit-only entry carrying them is degenerate and matches
        // real open behavior by granting nothing.
        let identity = evaluatedIdentity
        let acl = WindowsRawAcl(entries: [
            .init(permission: .genericRead, trustee: evaluatedTrustee)
        ])
        let sd = makeSelfRelativeSD(dacl: .acl(acl))

        let granted = try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)

        #expect(granted == [])

    }


    @Test
    func `ForCurrentProcess matches explicit current identity`() throws {

        let user = try PlatformAccountSystem().currentIdentity()
        try requireSidBasedEvaluation(of: user)
        let acl = WindowsRawAcl(entries: [
            .init(permission: fileGenericRead, trustee: .everyone)
        ])
        let sd = makeSelfRelativeSD(dacl: .acl(acl))

        let byToken = try WindowsAccessChecker().effectiveAccessMaskForCurrentProcess(whenAccessing: sd)
        let bySid = try WindowsAccessChecker().effectiveAccessMask(for: user, whenAccessing: sd)

        #expect(byToken == fileGenericRead)
        #expect(byToken == bySid)

    }


    // White-box smoke test: the implementation shares one process-wide Authz resource
    // manager, so this hammers concurrent context creation and checks against that one
    // handle. It can only demonstrate that concurrent use is safe (a crash or wrong
    // mask would surface here); it cannot observe whether sharing actually happens.
    @Test
    func `Concurrent evaluations return correct masks`() async throws {

        let identity = evaluatedIdentity
        let permission = [.readData, .writeAttributes, .synchronize] as WindowsAccessMask

        try await withThrowingTaskGroup(of: WindowsAccessMask.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    let acl = WindowsRawAcl(entries: [
                        .init(permission: permission, trustee: .init(sid: identity.rawId, type: .user))
                    ])
                    let sd = WindowsAbsoluteSecurityDescriptor(
                        dacl: .acl(acl),
                        owner: .system,
                        group: .system
                    ).makeSelfRelative()
                    return try WindowsAccessChecker().effectiveAccessMask(for: identity, whenAccessing: sd)
                }
            }
            for try await granted in group {
                #expect(granted == permission)
            }
        }

    }

}

#endif
