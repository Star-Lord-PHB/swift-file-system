#if canImport(WinSDK)

import PlatformCLib



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

    init(pacl: consuming UnsafeOwnedAutoPointer<ACL>) {
        self.pacl = pacl
        precondition(self.isValid(), "Invalid ACL pointer")
    }

    public init(entries: [ExplicitAccess] = []) {
        let pacl = UnsafeMutablePointer<ACL>.allocate(capacity: 1)
        InitializeAcl(pacl, 0, DWORD(ACL_REVISION))
        self.init(pacl: .init(owningPointer: pacl, allocator: .swift))
        if !entries.isEmpty {
            self.addEntries(entries)
        }
    }

    public init(unsafeOwningAclPtr: PACL, allocator: WindowsMemoryAllocatorType) {
        self.init(pacl: .init(owningPointer: unsafeOwningAclPtr, allocator: allocator.mappedInternalAllocatorType))
    }

    public func isValid() -> Bool {
        return IsValidAcl(pacl.unsafeRawPtr)
    }

    public mutating func addEntries(_ entries: [ExplicitAccess]) {
        let newPacl = try! WindowsAPI.setEntriesInAcl(for: self.pacl, entires: entries.map(\.unsafeRawExplicitAccess))
        self = .init(pacl: newPacl)
    }

    public static var emptyAcl: WindowsRawAcl { .init() }

    public struct View: ~Escapable, WindowsRawAclNotNullableAclProtocol {

        let pacl: UnsafeUnownedPointer<ACL>

        @_lifetime(copy pacl)
        init(pacl: UnsafeUnownedPointer<ACL>) {
            precondition(IsValidAcl(pacl.unsafeRawPtr), "Invalid ACL pointer")
            self.pacl = pacl
        }

        public func isValid() -> Bool {
            return IsValidAcl(pacl.unsafeRawPtr)
        }

    }

}


extension WindowsRawAcl {

    public func withUnsafePACL<R, E>(_ operation: (PACL) throws(E) -> R) throws(E) -> R where E : Error, R : ~Copyable {
        return try operation(pacl.unsafeRawPtr)
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

}



extension WindowsRawAcl.View {

    public func withUnsafePACL<R, E>(_ operation: (PACL) throws(E) -> R) throws(E) -> R where E : Error, R : ~Copyable {
        return try operation(pacl.unsafeRawPtr)
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

}



public struct WindowsRawAclView: ~Escapable, WindowRawAclProtocol {

    let pacl: UnsafeUnownedPointer<ACL>?
    public let aclDefaulted: Bool

    @_lifetime(copy pacl)
    init(pacl: UnsafeUnownedPointer<ACL>?, aclDefaulted: Bool) {
        precondition(IsValidAcl(pacl?.unsafeRawPtr), "Invalid ACL pointer")
        self.pacl = pacl
        self.aclDefaulted = aclDefaulted
    }

    @_lifetime(copy psd)
    init?(psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {
        
        precondition(IsValidSecurityDescriptor(psd.unsafeRawPtr), "Invalid SECURITY_DESCRIPTOR pointer")
        
        var aclPtr = nil as PACL?
        var aclPresent = false as WindowsBool
        var aclDefaulted = false as WindowsBool

        switch type {
            case .dacl: GetSecurityDescriptorDacl(psd.unsafeRawPtr, &aclPresent, &aclPtr, &aclDefaulted)
            case .sacl: GetSecurityDescriptorSacl(psd.unsafeRawPtr, &aclPresent, &aclPtr, &aclDefaulted)
        }

        guard aclPresent.boolValue else { return nil }

        self.pacl = switch aclPtr {
            case .some(let aclPtr): .init(unownedPointer: aclPtr)
            case .none: nil
        }
        self.aclDefaulted = aclDefaulted.boolValue

    }

    @_lifetime(borrow psd)
    init?(psd: borrowing UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {
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
            case .some(let pacl): try operation(pacl.unsafeRawPtr)
            case .none: try operation(nil)
        }
    }
    public var isNull: Bool { Self._isNull(self) }
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

}



public struct WindowsRawAceView: ~Escapable {

    let pace: UnsafeUnownedRawPointer

    @_lifetime(copy pace)
    init(pace: UnsafeUnownedRawPointer) {
        self.pace = pace
    }

    @_lifetime(immortal)
    init(unsafeBorrowingAcePtr: LPVOID) {
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
                    sid = .init(psid: .init(unownedResource: allowAcePtr.pointer(to: \.SidStart).unsafeRawPtr))
                }
                case .deny: do {
                    let denyAcePtr = pace.bindMemory(to: ACCESS_DENIED_ACE.self, capacity: 1)
                    mask = .init(rawValue: denyAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: denyAcePtr.pointer(to: \.SidStart).unsafeRawPtr))
                }
                case .audit: do {
                    let auditAcePtr = pace.bindMemory(to: SYSTEM_AUDIT_ACE.self, capacity: 1)
                    mask = .init(rawValue: auditAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: auditAcePtr.pointer(to: \.SidStart).unsafeRawPtr))
                }
                case .alarm: do {
                    let alarmAcePtr = pace.bindMemory(to: SYSTEM_ALARM_ACE.self, capacity: 1)
                    mask = .init(rawValue: alarmAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: alarmAcePtr.pointer(to: \.SidStart).unsafeRawPtr))
                }
            }

            return (sid: sid, mask: mask)
        }
    }

}

#endif 