import SystemPackage


extension FileInfo {

    public struct PlatformSecurityInfo: Sendable, Equatable, Hashable {
        
        #if canImport(WinSDK)

        public let effectiveAccess: WindowsSecurityDescriptor.WindowsAccessMask
        public let owner: String 
        public let group: String

        #else 

        public let permission: FilePermissions
        public let uid: UInt32
        public let gid: UInt32

        #endif // canImport(WinSDK)

    }

}



extension FileInfo.PlatformSecurityInfo: CustomStringConvertible {

    #if canImport(WinSDK)

    @inlinable
    public var description: String {
        "SecurityInfo(effectiveAccess: \(effectiveAccess), owner: \(owner), group: \(group))"
    }

    #else 

    @inlinable
    public var description: String {
        "SecurityInfo(permission: \(permission), uid: \(uid), gid: \(gid))"
    }
    
    #endif

}
