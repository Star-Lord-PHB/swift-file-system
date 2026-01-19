import FileSystemCore



public final class PlatformAPI: PlatformAPIProtocol {

    public init() { }

}



extension PlatformAPI {

    public func accountName(for identity: PlatformIdentity) throws(FileError) -> String? {
        return try catchSystemError(operationDescription: .queryingAccountName(for: identity)) { () throws(SystemError) in
            try InternalPlatformAPI.accountName(for: identity)
        }
    }


    #if canImport(WinSDK)
    public func identity(forAccountName name: String) throws(FileError) -> PlatformIdentity? {
        return try catchSystemError(operationDescription: .queryingIdentity(forAccountName: name)) { () throws(SystemError) in
            try InternalPlatformAPI.identity(forAccountName: name)
        }
    }
    #else 
    public func identity(forAccountName name: String, kind: PlatformIdentity.Kind) throws(FileError) -> PlatformIdentity? {
        return try catchSystemError(operationDescription: .queryingIdentity(forAccountName: name)) { () throws(SystemError) in
            try InternalPlatformAPI.identity(forAccountName: name, kind: kind)
        }
    }
    #endif 


    public func currentIdentity() throws(FileError) -> PlatformIdentity {
        return try catchSystemError(operationDescription: .queryingCurrentIdentity()) { () throws(SystemError) in
            try InternalPlatformAPI.currentIdentity()
        }
    }


    #if canImport(WinSDK)
    public func effectiveAccessMask(
        for identity: PlatformIdentity, 
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(FileError) -> WindowsAccessMask {
        return try catchSystemError(operationDescription: .queryingEffectiveAccessMask(for: identity)) { () throws(SystemError) in
            try InternalPlatformAPI.effectiveAccessMask(for: identity, whenAccessing: securityDescriptor)
        }
    }


    public func effectiveAccessMaskForCurrentProcess(
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(FileError) -> WindowsAccessMask {
        try effectiveAccessMask(for: currentIdentity(), whenAccessing: securityDescriptor)
    }
    #endif 

}