#if canImport(WinSDK)
import FileSystemCore


/// APIs for evaluating the effective access that would be granted by a Windows security descriptor 
/// to an identity.
public struct WindowsAccessChecker: Sendable {

    public init() { }

}



extension WindowsAccessChecker {

    /// Evaluates the access mask the given identity would be granted by the security descriptor.
    /// - Parameters:
    ///   - identity: The identity to evaluate.
    ///   - securityDescriptor: The security descriptor to evaluate against.
    /// 
    /// - Attention: To evaluate the effective access mask for the current process, use 
    ///              ``effectiveAccessMaskForCurrentProcess(whenAccessing:)`` instead, which uses the 
    ///              actual process token instead of the SID of the current account.
    /// 
    /// - Attention: The security descriptor must carry an owner. Evaluating one without it fails with
    ///              an invalid-parameter error
    public func effectiveAccessMask(
        for identity: PlatformIdentity,
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) -> WindowsAccessMask {
        return try catchLowLevelError(operation: .queryEffectiveAccessMask) { () throws(LowLevelError) in
            try InternalPlatformAPI.effectiveAccessMask(for: identity, whenAccessing: securityDescriptor)
        }
    }


    /// Evaluates the access mask the calling process would be granted by the security descriptor.
    ///
    /// The evaluation context is built from the process token, so the token's actual group list — including
    /// deny-only and restricted SIDs — is reflected. This is more faithful than calling 
    /// ``effectiveAccessMask(for:whenAccessing:)`` with the current identity when trying to evaluate 
    /// the access for the current process.
    /// 
    /// - Attention: The security descriptor must carry an owner. Evaluating one without it fails with
    ///              an invalid-parameter error
    public func effectiveAccessMaskForCurrentProcess(
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) -> WindowsAccessMask {
        return try catchLowLevelError(operation: .queryEffectiveAccessMask) { () throws(LowLevelError) in
            try InternalPlatformAPI.effectiveAccessMaskForCurrentProcess(whenAccessing: securityDescriptor)
        }
    }

}
#endif
