import PlatformCLib


public struct PlatformIdentity: Sendable {

    #if canImport(WinSDK)

    public let rawId: WindowsSid


    public init(rawId: WindowsSid) {
        self.rawId = rawId
    }

    #else 

    public enum Kind: Sendable, Equatable {
        case user
        case group
    }

    public let rawId: UInt32
    public let kind: Kind

    public init(rawId: UInt32, kind: Kind) {
        self.rawId = rawId
        self.kind = kind
    }

    #endif

}



extension PlatformIdentity: Equatable, Hashable {}



extension PlatformIdentity: CustomStringConvertible {

    public var description: String {
        #if canImport(WinSDK)
        rawId.string
        #else 
        "\(rawId) (\(kind == .user ? "uid" : "gid"))"
        #endif
    }

}