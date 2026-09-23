#if canImport(WinSDK)

import PlatformCLib


/// Wrapper of the Windows EXPLICIT_ACCESSW structure, used for editing an ACL by adding new rules.
public struct WindowsExplicitAccess: @unchecked Sendable {

    private var ea: EXPLICIT_ACCESSW
    private var sid: WindowsSid

    init(ea: EXPLICIT_ACCESSW, sidFreeingFunc: @escaping (PSID) -> Void) {
        self.ea = ea
        self.sid = .init(unsafeOwningPSid: ea.Trustee.ptstrName, freeingFunc: sidFreeingFunc)
        precondition(AccessMode(rawValue: self.ea.grfAccessMode.rawValue) != nil, "Invalid access mode value: \(self.ea.grfAccessMode)")
        precondition(TrusteeType(rawValue: self.ea.Trustee.TrusteeType.rawValue) != nil, "Invalid trustee type value: \(self.ea.Trustee.TrusteeType)")
    }

    /// Creates a new WindowsExplicitAccess with the given components.
    /// 
    /// - Parameters:
    ///   - permission: The requested access mask of the new rule.
    ///   - accessMode: The mode for treating the access mask.
    ///   - inheritance: The inheritance flags.
    ///   - trustee: The trustee the new rule applies to.
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

    /// The access mask of the rule.
    public var permission: WindowsAccessMask {
        get { .init(rawValue: ea.grfAccessPermissions) }
        set { ea.grfAccessPermissions = newValue.rawValue }
    }

    /// The mode for treating the access mask.
    public var accessMode: AccessMode {
        get { .init(rawValue: ea.grfAccessMode.rawValue)! }
        set { ea.grfAccessMode = newValue.rawAccessMode }
    }

    /// The inheritance flags.
    public var inheritance: Inheritance {
        get { .init(rawValue: ea.grfInheritance) }
        set { ea.grfInheritance = newValue.rawValue }
    }

    /// The trustee the rule applies to.
    public var trustee: RawTrustee {
        get { .init(sid: sid, type: .init(rawValue: ea.Trustee.TrusteeType.rawValue)!) }
        set { 
            ea.Trustee.TrusteeType = newValue.type.rawTrusteeType
            ea.Trustee.ptstrName = newValue.sid.psid.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            sid = newValue.sid
        }
    }

    /// Access the underlying EXPLICIT_ACCESSW structure in a closure.
    /// - Parameter operation: The closure for accessing the underlying EXPLICIT_ACCESSW structure.
    /// 
    /// - Warning: Do not return or store the EXPLICIT_ACCESSW outside of the closure.
    public func withUnsafeRawExplicitAccess<R: ~Copyable, E: Error>(_ operation: (EXPLICIT_ACCESSW) throws(E) -> R) throws(E) -> R {
        return try operation(ea)
    }
    
}



extension WindowsExplicitAccess {

    /// The mode for treating the access mask of a WindowsExplicitAccess.
    public enum AccessMode: ACCESS_MODE.RawValue, Sendable {
        case notUsed, grantAccess, setAccess, denyAccess, revokeAccess
        case setAuditSuccess, setAuditFailure
        /// The native raw ACCESS_MODE value.
        public var rawAccessMode: ACCESS_MODE { .init(rawValue: self.rawValue) }
    }

    /// The inheritance flags of a WindowsExplicitAccess.
    public struct Inheritance: Sendable, OptionSet {

        public let rawValue: DWORD

        public init(rawValue: DWORD) {
            self.rawValue = rawValue
        }

        /// `NO_INHERITANCE`
        public static let noInheritance: Inheritance = .init(rawValue: DWORD(NO_INHERITANCE))
        /// `SUB_OBJECTS_ONLY_INHERIT`
        public static let subFiles: Inheritance = .init(rawValue: DWORD(SUB_OBJECTS_ONLY_INHERIT))
        /// `SUB_CONTAINERS_ONLY_INHERIT`
        public static let subContainers: Inheritance = .init(rawValue: DWORD(SUB_CONTAINERS_ONLY_INHERIT))
        /// `SUB_CONTAINERS_AND_OBJECTS_INHERIT`
        public static let noPropagate: Inheritance = .init(rawValue: DWORD(INHERIT_NO_PROPAGATE))
        /// `INHERIT_ONLY`
        public static let inheritOnly: Inheritance = .init(rawValue: DWORD(INHERIT_ONLY))

        /// `SUB_CONTAINERS_AND_OBJECTS_INHERIT`
        public static let allSubItems: Inheritance = .init(rawValue: DWORD(SUB_CONTAINERS_AND_OBJECTS_INHERIT))

    }

    /// The trustee of a WindowsExplicitAccess, which is the identity the rule applies to.
    public struct RawTrustee: Sendable {
        /// The SID of the trustee.
        public var sid: WindowsSid
        /// The type of the trustee.
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

    /// The type of a RawTrustee.
    public enum TrusteeType: TRUSTEE_TYPE.RawValue, Sendable {
        case unknown, user, group, domain, alias, wellKnownGroup, deleted, invalid, computer
        /// The native raw TRUSTEE_TYPE value.
        public var rawTrusteeType: TRUSTEE_TYPE { .init(rawValue: self.rawValue) }
    }

}



/// An array of ``WindowsExplicitAccess``.
/// 
/// When trying to work with Windows native APIs, it is recomended to use this type instead of normal array of 
/// ``WindowsExplicitAccess``. This is because native APIs usually require a pointer to a contiguous buffer of 
/// `EXPLICIT_ACCESSW` structures, while the ``WindowsExplicitAccess`` type also includes a ``WindowsSid`` for
/// managing the lifetime of the SID in the trustee. As a result, the underlying storage of normal arrays of 
/// ``WindowsExplicitAccess`` is not a contiguous buffer of `EXPLICIT_ACCESSW`.
public struct WindowsExplicitAccessArray: ExpressibleByArrayLiteral, @unchecked Sendable {

    private var entries: [EXPLICIT_ACCESSW]
    private var sids: [WindowsSid]

    /// The number of ``WindowsExplicitAccess`` in the array.
    public var count: Int { entries.count }

    /// Whether the array is empty.
    public var isEmpty: Bool { entries.isEmpty }

    /// Creates a new WindowsExplicitAccessArray from a sequence of ``WindowsExplicitAccess``.
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

    /// Access the ``WindowsExplicitAccess`` at the given index.
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

    /// Appends a new ``WindowsExplicitAccess`` to the array.
    public mutating func append(_ entry: WindowsExplicitAccess) {
        entry.withUnsafeRawExplicitAccess { ea in 
            self.entries.append(ea)
        }
        self.sids.append(entry.trustee.sid)
    }

    /// Appends elements from a ``WindowsExplicitAccessArray`` to the array.
    public mutating func append(contentsOf newEntries: WindowsExplicitAccessArray) {
        entries.append(contentsOf: newEntries.entries)
        sids.append(contentsOf: newEntries.sids)
    }

    /// Appends elements from a sequence of ``WindowsExplicitAccess`` to the array.
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

    /// Access the underlying EXPLICIT_ACCESSW buffer in a closure.
    /// - Parameter operation: The closure for accessing the underlying EXPLICIT_ACCESSW buffer.
    public func withUnsafeRawExplicitAccessBuffer<R: ~Copyable, E: Error>(_ operation: (UnsafeBufferPointer<EXPLICIT_ACCESSW>) throws(E) -> R) throws(E) -> R {
        let span = entries.span
        return try span.withUnsafeBufferPointer(operation)
    }

} 

#endif
