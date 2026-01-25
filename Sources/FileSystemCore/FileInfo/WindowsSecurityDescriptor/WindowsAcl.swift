#if canImport(WinSDK)

import PlatformCLib
import BasicContainers



fileprivate protocol WindowRawAclProtocol: ~Copyable, ~Escapable {
    func withUnsafeNullablePACL<R: ~Copyable, E: Error>(_ operation: (PACL?) throws(E) -> R) throws(E) -> R
    var isNull: Bool { get }
    var aceCount: WORD { get }
    subscript(_ index: Int) -> WindowsRawAceView { @_lifetime(borrow self) get }
    func forEach<E: Error>(_ body: (WindowsRawAceView) throws(E) -> Void) throws(E)
    func map<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T) throws(E) -> [T]
    func compactMap<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T?) throws(E) -> [T]
    func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, WindowsRawAceView) throws(E) -> T
    ) throws(E) -> T
    func reduce<T: ~Copyable, E: Error>(
        into initialResult: consuming T, 
        _ updateAccumulatingResult: (inout T, WindowsRawAceView) throws(E) -> Void
    ) throws(E) -> T
    var first: WindowsRawAceView? { @_lifetime(borrow self) get }
    @_lifetime(borrow self)
    func first(where predicate: (WindowsRawAceView) throws -> Bool) rethrows -> WindowsRawAceView?
}



extension WindowRawAclProtocol where Self: ~Copyable & ~Escapable {

    static func _isNull(_ self: borrowing Self) -> Bool {
        return self.withUnsafeNullablePACL { pacl in pacl == nil }
    }

    static func _aceCount(_ self: borrowing Self) -> WORD {
        return self.withUnsafeNullablePACL { pacl in 
            pacl?.pointee.AceCount ?? 0
        }
    }

    @_lifetime(borrow this)
    static func _subscriptGet(_ this: borrowing Self, _ index: Int) -> WindowsRawAceView {
        precondition(index >= 0 && index < Int(this.aceCount), "Index out of bounds")
        let acePtr = this.withUnsafeNullablePACL { pacl in 
            switch pacl {
                case .some(let pacl): 
                    var acePtr = nil as LPVOID?
                    do throws(SystemError) {
                        try execThrowingCFunction {
                            GetAce(pacl, DWORD(index), &acePtr)
                        }
                        guard let acePtr else {
                            try SystemError.assertError()
                        }
                        return acePtr
                    } catch {
                        fatalError("Failed to get ACE at index \(index): \(error) (\(error.code))")
                    }
                case .none: fatalError("Index out of bounds")
            }
        }
        return .init(pace: .init(unownedPointer: acePtr))
    }

    static func _forEach<E: Error>(_ self: borrowing Self, _ body: (WindowsRawAceView) throws(E) -> Void) throws(E) {
        for i in 0 ..< Int(self.aceCount) {
            try body(self[i])
        }
    }


    static func _map<T, E: Error>(_ self: borrowing Self, _ transform: (WindowsRawAceView) throws(E) -> T) throws(E) -> [T] {
        var results = [T]()
        for i in 0 ..< Int(self.aceCount) {
            let result = try transform(self[i])
            results.append(result)
        }
        return results
    }


    static func _reduce<T: ~Copyable, E: Error>(
        _ self: borrowing Self, 
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, WindowsRawAceView) throws(E) -> T
    ) throws(E) -> T {
        var result = initialResult
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            result = try nextPartialResult(result, aceView)
        }
        return result
    }

    static func _compactMap<T, E: Error>(_ self: borrowing Self, _ transform: (WindowsRawAceView) throws(E) -> T?) throws(E) -> [T] {
        var results = [T]()
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            if let result = try transform(aceView) {
                results.append(result)
            }
        }
        return results
    }

    static func _reduce<T: ~Copyable, E: Error>(
        _ self: borrowing Self, 
        into initialResult: consuming T, 
        _ updateAccumulatingResult: (inout T, WindowsRawAceView) throws(E) -> Void
    ) throws(E) -> T {
        var result = initialResult
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            try updateAccumulatingResult(&result, aceView)
        }
        return result
    }

    @_lifetime(borrow this)
    static func _first(_ this: borrowing Self) -> WindowsRawAceView? {
        guard this.aceCount > 0 else { return nil }
        return this[0]
    }

    
    @_lifetime(borrow this)
    static func _first(_ this: borrowing Self, where predicate: (WindowsRawAceView) throws -> Bool) rethrows -> WindowsRawAceView? {
        for i in 0 ..< Int(this.aceCount) {
            let aceView = this[i]
            if try predicate(aceView) {
                return aceView
            }
        }
        return nil
    }

}



fileprivate protocol WindowsRawAclNotNullableAclProtocol: ~Copyable, ~Escapable, WindowRawAclProtocol {
    func withUnsafePACL<R: ~Copyable, E: Error>(_ operation: (PACL) throws(E) -> R) throws(E) -> R
}



extension WindowsRawAclNotNullableAclProtocol where Self: ~Copyable & ~Escapable {

    func withUnsafeNullablePACL<R: ~Copyable, E: Error>(_ operation: (PACL?) throws(E) -> R) throws(E) -> R {
        return try self.withUnsafePACL { (pacl: PACL) throws(E) in
            try operation(pacl)
        }
    }

}



public struct WindowsRawAcl: ~Copyable, WindowsRawAclNotNullableAclProtocol {

    private(set) var pacl: UnsafeOwnedAutoPointer<ACL>

    public var view: View {
        @_lifetime(borrow self)
        get {
            .init(pacl: pacl.unownedView())
        }
    }

    package init(pacl: consuming UnsafeOwnedAutoPointer<ACL>) {
        self.pacl = pacl
        precondition(self.isValid(), "Invalid ACL pointer")
    }

    public init(entries: WindowsExplicitAccessArray = []) {
        let pacl = UnsafeMutablePointer<ACL>.allocate(capacity: 1)
        InitializeAcl(pacl, DWORD(MemoryLayout<ACL>.size), DWORD(ACL_REVISION))
        self.init(pacl: .init(owningPointer: pacl, allocator: .swift))
        if !entries.isEmpty {
            self.addEntries(entries)
        }
    }

    public init(unsafeOwningAclPtr: PACL, allocator: WindowsMemoryAllocatorType) {
        self.init(pacl: .init(owningPointer: unsafeOwningAclPtr, allocator: allocator.mappedInternalAllocatorType))
    }

    fileprivate func isValid() -> Bool {
        return IsValidAcl(pacl.unsafelyCastedMutableRawPtr)
    }

    public mutating func addEntries(_ entries: WindowsExplicitAccessArray) {
        entries.withUnsafeRawExplicitAccessBuffer { ptr in
            let newPacl = try! WindowsAPI.setEntriesInAcl(for: self.pacl, entires: .init(unownedBuffer: ptr))
            self = .init(pacl: newPacl)
        }
    }

    public static var emptyAcl: WindowsRawAcl { .init() }

    public struct View: ~Escapable, WindowsRawAclNotNullableAclProtocol {

        let pacl: UnsafeUnownedPointer<ACL>

        @_lifetime(copy pacl)
        init(pacl: UnsafeUnownedPointer<ACL>) {
            precondition(IsValidAcl(pacl.unsafelyCastedMutableRawPtr), "Invalid ACL pointer")
            self.pacl = pacl
        }

    }

}


extension WindowsRawAcl {

    public func withUnsafePACL<R, E>(_ operation: (PACL) throws(E) -> R) throws(E) -> R where E : Error, R : ~Copyable {
        return try operation(pacl.unsafelyCastedMutableRawPtr)
    }
    public var isNull: Bool { false }
    public var aceCount: WORD { Self._aceCount(self) }
    public subscript(_ index: Int) -> WindowsRawAceView {
        @_lifetime(borrow self)
        get {
            Self._subscriptGet(self, index)
        }
    }
    public func forEach<E: Error>(_ body: (WindowsRawAceView) throws(E) -> Void) throws(E) {
        try Self._forEach(self, body)
    }
    public func map<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T) throws(E) -> [T] {
        return try Self._map(self, transform)
    }
    public func compactMap<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T?) throws(E) -> [T] {
        return try Self._compactMap(self, transform)
    }
    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, WindowsRawAceView) throws(E) -> T
    ) throws(E) -> T {
        return try Self._reduce(self, initialResult, nextPartialResult)
    }
    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: consuming T, 
        _ updateAccumulatingResult: (inout T, WindowsRawAceView) throws(E) -> Void
    ) throws(E) -> T {
        return try Self._reduce(self, into: initialResult, updateAccumulatingResult)
    }
    public var first: WindowsRawAceView? {
        @_lifetime(borrow self)
        get {
            Self._first(self)
        }
    }
    @_lifetime(borrow self)
    public func first(where predicate: (WindowsRawAceView) throws -> Bool) rethrows -> WindowsRawAceView? {
        return try Self._first(self, where: predicate)
    }

}



extension WindowsRawAcl.View {

    public func withUnsafePACL<R, E>(_ operation: (PACL) throws(E) -> R) throws(E) -> R where E : Error, R : ~Copyable {
        return try operation(pacl.unsafelyCastedMutableRawPtr)
    }
    public var isNull: Bool { false }
    public var aceCount: WORD { Self._aceCount(self) }
    public subscript(_ index: Int) -> WindowsRawAceView {
        @_lifetime(borrow self)
        get {
            Self._subscriptGet(self, index)
        }
    }
    public func forEach<E: Error>(_ body: (WindowsRawAceView) throws(E) -> Void) throws(E) {
        try Self._forEach(self, body)
    }
    public func map<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T) throws(E) -> [T] {
        return try Self._map(self, transform)
    }
    public func compactMap<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T?) throws(E) -> [T] {
        return try Self._compactMap(self, transform)
    }
    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, WindowsRawAceView) throws(E) -> T
    ) throws(E) -> T {
        return try Self._reduce(self, initialResult, nextPartialResult)
    }
    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: consuming T, 
        _ updateAccumulatingResult: (inout T, WindowsRawAceView) throws(E) -> Void
    ) throws(E) -> T {
        return try Self._reduce(self, into: initialResult, updateAccumulatingResult)
    }
    public var first: WindowsRawAceView? {
        @_lifetime(borrow self)
        get {
            Self._first(self)
        }
    }
    @_lifetime(borrow self)
    public func first(where predicate: (WindowsRawAceView) throws -> Bool) rethrows -> WindowsRawAceView? {
        return try Self._first(self, where: predicate)
    }

}



public struct WindowsRawAclView: ~Escapable, WindowRawAclProtocol {

    package let pacl: UnsafeUnownedPointer<ACL>?
    public let aclDefaulted: Bool

    @_lifetime(copy pacl)
    package init(pacl: UnsafeUnownedPointer<ACL>?, aclDefaulted: Bool) {
        precondition(IsValidAcl(pacl?.unsafelyCastedMutableRawPtr), "Invalid ACL pointer")
        self.pacl = pacl
        self.aclDefaulted = aclDefaulted
    }

    @_lifetime(copy psd)
    package init?(psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {
        
        precondition(IsValidSecurityDescriptor(psd.unsafelyCastedMutableRawPtr), "Invalid SECURITY_DESCRIPTOR pointer")
        
        var aclPtr = nil as PACL?
        var aclPresent = false as WindowsBool
        var aclDefaulted = false as WindowsBool

        switch type {
            case .dacl: GetSecurityDescriptorDacl(psd.unsafelyCastedMutableRawPtr, &aclPresent, &aclPtr, &aclDefaulted)
            case .sacl: GetSecurityDescriptorSacl(psd.unsafelyCastedMutableRawPtr, &aclPresent, &aclPtr, &aclDefaulted)
        }

        guard aclPresent.boolValue else { return nil }

        self.pacl = switch aclPtr {
            case .some(let aclPtr): .init(unownedPointer: aclPtr)
            case .none: nil
        }
        self.aclDefaulted = aclDefaulted.boolValue

    }

    @_lifetime(borrow psd)
    package init?(psd: borrowing UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {
        self.init(psd: psd.unownedView(), type: type)
    }

    @_lifetime(immortal)
    public init(unsafeBorrowingAclPtr: PACL, aclDefaulted: Bool) {
        self.pacl = .init(unownedPointer: unsafeBorrowingAclPtr)
        self.aclDefaulted = aclDefaulted
    }

}



extension WindowsRawAclView {

    public func withUnsafeNullablePACL<R: ~Copyable, E: Error>(_ operation: (PACL?) throws(E) -> R) throws(E) -> R {
        return switch self.pacl {
            case .some(let pacl): try operation(pacl.unsafelyCastedMutableRawPtr)
            case .none: try operation(nil)
        }
    }
    public var isNull: Bool { Self._isNull(self) }
    public var aceCount: WORD { Self._aceCount(self) }
    public subscript(_ index: Int) -> WindowsRawAceView {
        @_lifetime(borrow self)
        get {
            Self._subscriptGet(self, index) }
    }
    public func forEach<E: Error>(_ body: (WindowsRawAceView) throws(E) -> Void) throws(E) {
        try Self._forEach(self, body)
    }
    public func map<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T) throws(E) -> [T] {
        return try Self._map(self, transform)
    }
    public func compactMap<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T?) throws(E) -> [T] {
        return try Self._compactMap(self, transform)
    }
    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, WindowsRawAceView) throws(E) -> T
    ) throws(E) -> T {
        return try Self._reduce(self, initialResult, nextPartialResult)
    }
    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: consuming T, 
        _ updateAccumulatingResult: (inout T, WindowsRawAceView) throws(E) -> Void
    ) throws(E) -> T {
        return try Self._reduce(self, into: initialResult, updateAccumulatingResult)
    }
    public var first: WindowsRawAceView? {
        @_lifetime(borrow self)
        get {
            Self._first(self)
        }
    }
    @_lifetime(borrow self)
    public func first(where predicate: (WindowsRawAceView) throws -> Bool) rethrows -> WindowsRawAceView? {
        return try Self._first(self, where: predicate)
    }

}



public struct WindowsRawAceView: ~Escapable {

    package let pace: UnsafeUnownedRawPointer

    @_lifetime(copy pace)
    package init(pace: UnsafeUnownedRawPointer) {
        self.pace = pace
    }

    @_lifetime(immortal)
    package init(unsafeBorrowingAcePtr: LPVOID) {
        self.pace = .init(unownedPointer: unsafeBorrowingAcePtr)
    }

    public var type: WindowsACEType {
        let headerPtr = pace.bindMemory(to: ACE_HEADER.self, capacity: 1)
        return .init(rawValue: headerPtr.pointee.AceType)
    }

    public var flags: WindowsACEFlags {
        let headerPtr = pace.bindMemory(to: ACE_HEADER.self, capacity: 1)
        return .init(rawValue: headerPtr.pointee.AceFlags)
    }

    public var size: WORD {
        let headerPtr = pace.bindMemory(to: ACE_HEADER.self, capacity: 1)
        return headerPtr.pointee.AceSize
    }

    public var permission: (sid: WindowsSid.View, mask: WindowsAccessMask) {
        @_lifetime(copy self)
        get {
            let mask: WindowsAccessMask
            let sid: WindowsSid.View

            switch type {
                case .allow: do {
                    let allowAcePtr = pace.bindMemory(to: ACCESS_ALLOWED_ACE.self, capacity: 1)
                    mask = .init(rawValue: allowAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: allowAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .deny: do {
                    let denyAcePtr = pace.bindMemory(to: ACCESS_DENIED_ACE.self, capacity: 1)
                    mask = .init(rawValue: denyAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: denyAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .audit: do {
                    let auditAcePtr = pace.bindMemory(to: SYSTEM_AUDIT_ACE.self, capacity: 1)
                    mask = .init(rawValue: auditAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: auditAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .alarm: do {
                    let alarmAcePtr = pace.bindMemory(to: SYSTEM_ALARM_ACE.self, capacity: 1)
                    mask = .init(rawValue: alarmAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: alarmAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
            }

            return (sid: sid, mask: mask)
        }
    }

}



public struct WindowsExplicitAccess: Sendable {
    public var permission: WindowsAccessMask
    public var accessMode: AccessMode
    public var inheritance: Inheritance
    public var trustee: RawTrustee

    /// > Warning: 
    /// > The provided EXPLICIT_ACCESSW value contains a unowned pointer to a SID, 
    /// > MUST ensure that the WindowsExplicitAccess value outlives the lifetime of the EXPLICIT_ACCESSW value.
    public func withUnsafeRawExplicitAccess<R: ~Copyable, E: Error>(_ operation: (EXPLICIT_ACCESSW) throws(E) -> R) throws(E) -> R {
        var ea = EXPLICIT_ACCESSW()
        ea.grfAccessPermissions = permission.rawValue
        ea.grfAccessMode = accessMode.rawAccessMode
        ea.grfInheritance = inheritance.rawValue
        ea.Trustee = TRUSTEE_W(
            pMultipleTrustee: nil,
            MultipleTrusteeOperation: NO_MULTIPLE_TRUSTEE,
            TrusteeForm: TRUSTEE_IS_SID,
            TrusteeType: trustee.type.rawTrusteeType,
            ptstrName: trustee.sid.psid.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
        )
        return try operation(ea)
    }

    public init(
        permission: WindowsAccessMask, 
        accessMode: AccessMode = .grantAccess, 
        inheritance: Inheritance = .noInheritance, 
        trustee: RawTrustee
    ) {
        self.permission = permission
        self.accessMode = accessMode
        self.inheritance = inheritance
        self.trustee = trustee
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
        public static var annonymous: RawTrustee { .init(sid: .annonymous, type: .wellKnownGroup) }
        public static var creatorOwner: RawTrustee { .init(sid: .everyone, type: .wellKnownGroup) }
        public static var creatorGroup: RawTrustee { .init(sid: .everyone, type: .wellKnownGroup) }

    }


    public enum TrusteeType: TRUSTEE_TYPE.RawValue, Sendable {
        case unknown, user, group, domain, alias, wellKnownGroup, deleted, invalid, computer
        public var rawTrusteeType: TRUSTEE_TYPE { .init(rawValue: self.rawValue) }
    }

}



public struct WindowsExplicitAccessArray: ExpressibleByArrayLiteral, Sendable {

    private var entries: [WindowsExplicitAccess]

    public var count: Int { entries.count }

    public var isEmpty: Bool { entries.isEmpty }

    public init<S: Sequence>(_ entries: S) where S.Element == WindowsExplicitAccess {
        self.entries = .init(entries)
    }

    public init(arrayLiteral elements: WindowsExplicitAccess...) {
        self.entries = .init(elements)
    }

    public subscript(_ index: Int) -> WindowsExplicitAccess {
        get { entries[index] }
        set { entries[index] = newValue }
    }

    public mutating func append(_ entry: WindowsExplicitAccess) {
        entries.append(entry)
    }

    public mutating func append(contentsOf newEntries: WindowsExplicitAccessArray) {
        entries.append(contentsOf: newEntries.entries)
    }

    public mutating func append<S: Sequence>(contentsOf newEntries: S) where S.Element == WindowsExplicitAccess {
        entries.append(contentsOf: newEntries)
    }

    public func withUnsafeRawExplicitAccessBuffer<R: ~Copyable, E: Error>(_ operation: (UnsafeBufferPointer<EXPLICIT_ACCESSW>) throws(E) -> R) throws(E) -> R {
        let rawEntries = RigidArray<EXPLICIT_ACCESSW>(capacity: count) { outSpan in 
            for i in 0 ..< count {
                entries[i].withUnsafeRawExplicitAccess { rawEA in
                    outSpan.append(rawEA)
                }
            }
        }
        return try rawEntries.span.withUnsafeBufferPointer(operation)
    }

    public func withUnsafeMutableRawExplicitAccessBuffer<R: ~Copyable, E: Error>(_ operation: (UnsafeMutableBufferPointer<EXPLICIT_ACCESSW>) throws(E) -> R) throws(E) -> R {
        var rawEntries = RigidArray<EXPLICIT_ACCESSW>(capacity: count) { outSpan in 
            for i in 0 ..< count {
                entries[i].withUnsafeRawExplicitAccess { rawEA in
                    outSpan.append(rawEA)
                }
            }
        }
        var mutableSpan = rawEntries.mutableSpan
        return try mutableSpan.withUnsafeMutableBufferPointer(operation)
    }

} 

#endif 