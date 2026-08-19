#if canImport(WinSDK)

import PlatformCLib


public struct WindowsExplicitAccess: @unchecked Sendable {

    private var ea: EXPLICIT_ACCESSW
    private var sid: WindowsSid

    init(ea: EXPLICIT_ACCESSW, sidFreeingFunc: @escaping (PSID) -> Void) {
        self.ea = ea
        self.sid = .init(unsafeOwningPSid: ea.Trustee.ptstrName, freeingFunc: sidFreeingFunc)
        precondition(AccessMode(rawValue: self.ea.grfAccessMode.rawValue) != nil, "Invalid access mode value: \(self.ea.grfAccessMode)")
        precondition(TrusteeType(rawValue: self.ea.Trustee.TrusteeType.rawValue) != nil, "Invalid trustee type value: \(self.ea.Trustee.TrusteeType)")
    }

    public init(
        permission: WindowsAccessMask, 
        accessMode: AccessMode = .grantAccess, 
        inheritance: Inheritance = .noInheritance,
        trustee: RawTrustee
    ) {
        self.ea = EXPLICIT_ACCESSW()
        self.ea.grfAccessPermissions = permission.rawValue
        self.ea.grfAccessMode = accessMode.rawAccessMode
        self.ea.grfInheritance = inheritance.rawValue
        self.ea.Trustee = TRUSTEE_W(
            pMultipleTrustee: nil,
            MultipleTrusteeOperation: NO_MULTIPLE_TRUSTEE,
            TrusteeForm: TRUSTEE_IS_SID,
            TrusteeType: trustee.type.rawTrusteeType,
            ptstrName: trustee.sid.psid.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
        )
        self.sid = trustee.sid
    }

    public var permission: WindowsAccessMask {
        get { .init(rawValue: ea.grfAccessPermissions) }
        set { ea.grfAccessPermissions = newValue.rawValue }
    }

    public var accessMode: AccessMode {
        get { .init(rawValue: ea.grfAccessMode.rawValue)! }
        set { ea.grfAccessMode = newValue.rawAccessMode }
    }

    public var inheritance: Inheritance {
        get { .init(rawValue: ea.grfInheritance) }
        set { ea.grfInheritance = newValue.rawValue }
    }

    public var trustee: RawTrustee {
        get { .init(sid: sid, type: .init(rawValue: ea.Trustee.TrusteeType.rawValue)!) }
        set { 
            ea.Trustee.TrusteeType = newValue.type.rawTrusteeType
            ea.Trustee.ptstrName = newValue.sid.psid.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            sid = newValue.sid
        }
    }

    public func withUnsafeRawExplicitAccess<R: ~Copyable, E: Error>(_ operation: (EXPLICIT_ACCESSW) throws(E) -> R) throws(E) -> R {
        return try operation(ea)
    }
    
}



extension WindowsExplicitAccess {

    public enum AccessMode: ACCESS_MODE.RawValue, Sendable {
        case notUsed, grantAccess, setAccess, denyAccess, revokeAccess
        case setAuditSuccess, setAuditFailure
        public var rawAccessMode: ACCESS_MODE { .init(rawValue: self.rawValue) }
    }

    public struct Inheritance: Sendable, OptionSet {

        public let rawValue: DWORD

        public init(rawValue: DWORD) {
            self.rawValue = rawValue
        }

        public static let noInheritance: Inheritance = .init(rawValue: DWORD(NO_INHERITANCE))
        public static let subFiles: Inheritance = .init(rawValue: DWORD(SUB_OBJECTS_ONLY_INHERIT))
        public static let subContainers: Inheritance = .init(rawValue: DWORD(SUB_CONTAINERS_ONLY_INHERIT))
        public static let noPropagate: Inheritance = .init(rawValue: DWORD(INHERIT_NO_PROPAGATE))
        public static let inheritOnly: Inheritance = .init(rawValue: DWORD(INHERIT_ONLY))

        public static let allSubItems: Inheritance = .init(rawValue: DWORD(SUB_CONTAINERS_AND_OBJECTS_INHERIT))

    }

    public struct RawTrustee: Sendable {
        public var sid: WindowsSid
        public var type: TrusteeType
        public init(sid: WindowsSid, type: TrusteeType) {
            self.sid = sid
            self.type = type
        }

        public static var everyone: RawTrustee { .init(sid: .everyone, type: .wellKnownGroup) }
        public static var administrators: RawTrustee { .init(sid: .administrators, type: .group) }
        public static var system: RawTrustee { .init(sid: .system, type: .user) }
        public static var authenticatedUsers: RawTrustee { .init(sid: .authenticatedUsers, type: .wellKnownGroup) }
        public static var users: RawTrustee { .init(sid: .users, type: .wellKnownGroup) }
        public static var localService: RawTrustee { .init(sid: .localService, type: .wellKnownGroup) }
        public static var networkService: RawTrustee { .init(sid: .networkService, type: .wellKnownGroup) }
        public static var anonymous: RawTrustee { .init(sid: .anonymous, type: .wellKnownGroup) }
        public static var creatorOwner: RawTrustee { .init(sid: .creatorOwner, type: .wellKnownGroup) }
        public static var creatorGroup: RawTrustee { .init(sid: .creatorGroup, type: .wellKnownGroup) }

    }

    public enum TrusteeType: TRUSTEE_TYPE.RawValue, Sendable {
        case unknown, user, group, domain, alias, wellKnownGroup, deleted, invalid, computer
        public var rawTrusteeType: TRUSTEE_TYPE { .init(rawValue: self.rawValue) }
    }

}



public struct WindowsExplicitAccessArray: ExpressibleByArrayLiteral, @unchecked Sendable {

    private var entries: [EXPLICIT_ACCESSW]
    private var sids: [WindowsSid]

    public var count: Int { entries.count }

    public var isEmpty: Bool { entries.isEmpty }

    public init<S: Sequence>(_ entries: S) where S.Element == WindowsExplicitAccess {
        self.entries = []
        self.sids = []
        let underestimatedCount = entries.underestimatedCount
        self.entries.reserveCapacity(underestimatedCount)
        self.sids.reserveCapacity(underestimatedCount)
        for entry in entries {
            entry.withUnsafeRawExplicitAccess { ea in 
                self.entries.append(ea)
            }
            self.sids.append(entry.trustee.sid)
        }
    }

    public init(arrayLiteral elements: WindowsExplicitAccess...) {
        self.entries = []
        self.sids = []
        self.entries.reserveCapacity(elements.count)
        self.sids.reserveCapacity(elements.count)
        for entry in elements {
            entry.withUnsafeRawExplicitAccess { ea in 
                self.entries.append(ea)
            }
            self.sids.append(entry.trustee.sid)
        }
    }

    public subscript(_ index: Int) -> WindowsExplicitAccess {
        get { 
            .init(
                permission: .init(rawValue: entries[index].grfAccessPermissions), 
                accessMode: .init(rawValue: entries[index].grfAccessMode.rawValue)!, 
                inheritance: .init(rawValue: entries[index].grfInheritance), 
                trustee: .init(sid: sids[index], type: .init(rawValue: entries[index].Trustee.TrusteeType.rawValue)!)
            )
        }
        set { 
            self.entries[index].grfAccessPermissions = newValue.permission.rawValue
            self.entries[index].grfAccessMode = newValue.accessMode.rawAccessMode
            self.entries[index].grfInheritance = newValue.inheritance.rawValue
            self.entries[index].Trustee.TrusteeType = newValue.trustee.type.rawTrusteeType
            self.entries[index].Trustee.ptstrName = newValue.trustee.sid.psid.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            self.sids[index] = newValue.trustee.sid
        }
    }

    public mutating func append(_ entry: WindowsExplicitAccess) {
        entry.withUnsafeRawExplicitAccess { ea in 
            self.entries.append(ea)
        }
        self.sids.append(entry.trustee.sid)
    }

    public mutating func append(contentsOf newEntries: WindowsExplicitAccessArray) {
        entries.append(contentsOf: newEntries.entries)
        sids.append(contentsOf: newEntries.sids)
    }

    public mutating func append<S: Sequence>(contentsOf newEntries: S) where S.Element == WindowsExplicitAccess {
        let underestimatedCount = newEntries.underestimatedCount
        self.entries.reserveCapacity(self.entries.count + underestimatedCount)
        self.sids.reserveCapacity(self.sids.count + underestimatedCount)
        for entry in newEntries {
            entry.withUnsafeRawExplicitAccess { ea in 
                self.entries.append(ea)
            }
            self.sids.append(entry.trustee.sid)
        }
    }

    public func withUnsafeRawExplicitAccessBuffer<R: ~Copyable, E: Error>(_ operation: (UnsafeBufferPointer<EXPLICIT_ACCESSW>) throws(E) -> R) throws(E) -> R {
        let span = entries.span
        return try span.withUnsafeBufferPointer(operation)
    }

} 

#endif