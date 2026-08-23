#if canImport(WinSDK)
import FileSystemCore


/// Evaluates the effective access a given identity would be granted by a Windows security
/// descriptor, using the system's Authz access-check machinery (the API family Microsoft
/// designates as the replacement for `GetEffectiveRightsFromAcl`).
///
/// The security descriptor is evaluated as-is, for any kind of securable object:
/// no generic-rights mapping takes place during evaluation. Windows maps `GENERIC_*`
/// bits to object-specific rights when an inheritable ACE is instantiated onto a child
/// object, not at access-check time; a non-inherit-only ACE carrying unmapped generic
/// bits (only constructible through raw ACL APIs) contributes nothing here, which
/// matches how real opens behave against such degenerate ACEs.
///
/// The security descriptor must carry an owner; evaluating one without it fails with
/// an invalid-parameter error. An absent DACL is treated like a null one (unprotected,
/// full grant), matching kernel access-check semantics.
///
/// An identity that is granted nothing yields an empty access mask; only evaluation
/// failures throw.
public struct WindowsAccessChecker: Sendable {

    public init() { }

}



extension WindowsAccessChecker {

    /// Returns the access mask the given identity would be granted by the security descriptor.
    ///
    /// The evaluation context is derived from the identity's SID alone: group membership is
    /// resolved from the account database, so token-carried states of any live logon session
    /// (deny-only SIDs, restricted tokens) are not reflected. To evaluate the calling process
    /// itself, prefer ``effectiveAccessMaskForCurrentProcess(whenAccessing:)``, which uses
    /// the actual process token.
    public func effectiveAccessMask(
        for identity: PlatformIdentity,
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) -> WindowsAccessMask {
        return try catchLowLevelError(operation: .queryEffectiveAccessMask) { () throws(LowLevelError) in
            try InternalPlatformAPI.effectiveAccessMask(for: identity, whenAccessing: securityDescriptor)
        }
    }


    /// Returns the access mask the calling process would be granted by the security descriptor.
    ///
    /// The evaluation context is built from the process token, so the token's actual group
    /// list — including deny-only and restricted SIDs — is reflected. This is more faithful
    /// for the current process than ``effectiveAccessMask(for:whenAccessing:)`` with the
    /// current identity, which re-derives group membership from the SID.
    public func effectiveAccessMaskForCurrentProcess(
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) -> WindowsAccessMask {
        return try catchLowLevelError(operation: .queryEffectiveAccessMask) { () throws(LowLevelError) in
            try InternalPlatformAPI.effectiveAccessMaskForCurrentProcess(whenAccessing: securityDescriptor)
        }
    }

}
#endif
