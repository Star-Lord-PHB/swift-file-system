import PlatformCLib


public struct PlatformIdentity: Sendable {
    
    #if canImport(WinSDK)
    public typealias RawID = WindowsSid
    #else
    public typealias RawID = UInt32
    #endif
    
    #if canImport(WinSDK)
    public enum PlatformKind: Sendable, RawRepresentable, Equatable {
        case user
        case group
        case domain
        case alias
        case wellknownGroup
        case deletedAccount
        case invalid
        case unknown
        case computer
        case label
        case logonSession
        
        public init(rawValue: SID_NAME_USE) {
            switch rawValue {
                case SidTypeUser: self = .user
                case SidTypeGroup: self = .group
                case SidTypeDomain: self = .domain
                case SidTypeAlias: self = .alias
                case SidTypeWellKnownGroup: self = .wellknownGroup
                case SidTypeDeletedAccount: self = .deletedAccount
                case SidTypeInvalid: self = .invalid
                case SidTypeUnknown: self = .unknown
                case SidTypeComputer: self = .computer
                case SidTypeLabel: self = .label
                case SidTypeLogonSession: self = .logonSession
                default: self = .unknown
            }
        }
        
        public var rawValue: SID_NAME_USE {
            return switch self {
                case .user: SidTypeUser
                case .group: SidTypeGroup
                case .domain: SidTypeDomain
                case .alias: SidTypeAlias
                case .wellknownGroup: SidTypeWellKnownGroup
                case .deletedAccount: SidTypeDeletedAccount
                case .invalid: SidTypeInvalid
                case .unknown: SidTypeUnknown
                case .computer: SidTypeComputer
                case .label: SidTypeLabel
                case .logonSession: SidTypeLogonSession
            }
        }
    }
    #else
    public enum PlatformKind: Sendable, Equatable {
        case user
        case group
    }
    #endif

    public let rawId: RawID
    public let platformKind: PlatformKind
    
    public init(rawId: RawID, platformKind: PlatformKind) {
        self.rawId = rawId
        self.platformKind = platformKind
    }

}



extension PlatformIdentity: Equatable, Hashable {
    
    #if canImport(WinSDK)
    public static func == (lhs: PlatformIdentity, rhs: PlatformIdentity) -> Bool {
        lhs.rawId == rhs.rawId
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawId)
    }
    #endif
    
}



extension PlatformIdentity: CustomStringConvertible {

    public var description: String {
        "\(rawId) (\(platformKind))"
    }

}



extension PlatformIdentity {
    
    public enum AccountNameResolvePreference: Sendable, Equatable {
        case preferUser, preferGroup
    }
    
}
