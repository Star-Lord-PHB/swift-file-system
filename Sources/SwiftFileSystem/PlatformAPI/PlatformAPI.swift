import FileSystemCore


public struct PlatformAPI: PlatformAPIProtocol {

    public init() { }

}



extension PlatformAPI {

    public func accountName(for identity: PlatformIdentity) throws(PlatformError) -> String? {
        return try catchLowLevelError(operation: .queryAccountNameFromIdentity) { () throws(LowLevelError) in
            try InternalPlatformAPI.accountName(for: identity)
        }
    }
    
    
    public func identity(
        forAccountName name: String,
        resolvePreference: PlatformIdentity.AccountNameResolvePreference = .preferUser
    ) throws(PlatformError) -> PlatformIdentity? {
        return try catchLowLevelError(operation: .queryIdentityfromName) { () throws(LowLevelError) in
            try InternalPlatformAPI.identity(forAccountName: name, resolvePreference: resolvePreference)
        }
    }


    public func currentIdentity() throws(PlatformError) -> PlatformIdentity {
        return try catchLowLevelError(operation: .queryCurrentIdentity) { () throws(LowLevelError) in
            try InternalPlatformAPI.currentIdentity()
        }
    }


    #if canImport(WinSDK)
    public func effectiveAccessMask(
        for identity: PlatformIdentity, 
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) -> WindowsAccessMask {
        return try catchLowLevelError(operation: .queryEffectiveAccessMask) { () throws(LowLevelError) in
            try InternalPlatformAPI.effectiveAccessMask(for: identity, whenAccessing: securityDescriptor)
        }
    }


    public func effectiveAccessMaskForCurrentProcess(
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) -> WindowsAccessMask {
        try effectiveAccessMask(for: currentIdentity(), whenAccessing: securityDescriptor)
    }
    #endif 

}
