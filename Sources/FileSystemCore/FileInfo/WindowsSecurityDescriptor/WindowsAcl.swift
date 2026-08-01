#if canImport(WinSDK)

import PlatformCLib
import struct SystemPackage.FilePermissions
import struct SystemPackage.CModeT


public protocol WindowRawAclProtocol: ~Copyable, ~Escapable {
    func withUnsafePACL<R: ~Copyable, E: Error>(_ operation: (PACL) throws(E) -> R) throws(E) -> R
}



extension WindowRawAclProtocol where Self: ~Copyable & ~Escapable {

    public var revision: BYTE {
        return self.withUnsafePACL { pacl in 
            pacl.pointee.AclRevision
        }
    }

    public var aceCount: WORD {
        return self.withUnsafePACL { pacl in 
            pacl.pointee.AceCount
        }
    }

    public subscript(_ index: Int) -> WindowsRawAceView {
        @_lifetime(borrow self)
        get {
            precondition(index >= 0 && index < Int(self.aceCount), "Index out of bounds")
            let acePtr = self.withUnsafePACL { pacl in 
                var acePtr = nil as LPVOID?
                do throws(LowLevelError) {
                    try execThrowingCFunction {
                        GetAce(pacl, DWORD(index), &acePtr)
                    }
                    guard let acePtr else {
                        try LowLevelError.assertError()
                    }
                    return acePtr
                } catch {
                    fatalError("Failed to get ACE at index \(index): \(error)")
                }
            }
            return .init(pace: .init(unownedPointer: acePtr))
        }
    }

    public func forEach<E: Error>(_ body: (WindowsRawAceView) throws(E) -> Void) throws(E) {
        for i in 0 ..< Int(self.aceCount) {
            try body(self[i])
        }
    }


    public func map<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T) throws(E) -> [T] {
        var results = [T]()
        for i in 0 ..< Int(self.aceCount) {
            let result = try transform(self[i])
            results.append(result)
        }
        return results
    }


    public func reduce<T: ~Copyable, E: Error>(
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

    public func compactMap<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T?) throws(E) -> [T] {
        var results = [T]()
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            if let result = try transform(aceView) {
                results.append(result)
            }
        }
        return results
    }

    public func _reduce<T: ~Copyable, E: Error>(
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

    public var first: WindowsRawAceView? {
        @_lifetime(borrow self)
        get {
            guard self.aceCount > 0 else { return nil }
            return self[0]
        }
    }

    
    @_lifetime(borrow self)
    public func first(where predicate: (WindowsRawAceView) throws -> Bool) rethrows -> WindowsRawAceView? {
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            if try predicate(aceView) {
                return aceView
            }
        }
        return nil
    }

}



public struct WindowsRawAcl: ~Copyable, WindowRawAclProtocol {

    private(set) var pacl: UnsafeOwnedAutoPointer<ACL>

    public var view: View {
        @_lifetime(borrow self)
        get {
            .init(pacl: pacl.unownedView())
        }
    }

    package init(pacl: consuming UnsafeOwnedAutoPointer<ACL>) {
        self.pacl = pacl
        precondition(IsValidAcl(self.pacl.unsafelyCastedMutableRawPtr), "Invalid ACL pointer")
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

    public mutating func addEntries(_ entries: WindowsExplicitAccessArray) {
        entries.withUnsafeRawExplicitAccessBuffer { ptr in
            let newPacl = try! Self.addEntries(.init(unownedBuffer: ptr), toAcl: self.pacl.unownedView())
            self = .init(pacl: newPacl)
        }
    }

    public func withUnsafePACL<R, E>(_ operation: (PACL) throws(E) -> R) throws(E) -> R where E : Error, R : ~Copyable {
        return try operation(pacl.unsafelyCastedMutableRawPtr)
    }

    public static var emptyAcl: WindowsRawAcl { .init() }

    public struct View: ~Escapable, WindowRawAclProtocol {

        let pacl: UnsafeUnownedPointer<ACL>

        @_lifetime(copy pacl)
        init(pacl: UnsafeUnownedPointer<ACL>) {
            precondition(IsValidAcl(pacl.unsafelyCastedMutableRawPtr), "Invalid ACL pointer")
            self.pacl = pacl
        }

        public func withUnsafePACL<R, E>(_ operation: (PACL) throws(E) -> R) throws(E) -> R where E : Error, R : ~Copyable {
            return try operation(pacl.unsafelyCastedMutableRawPtr)
        }

    }

}



extension WindowsRawAcl {

    package static func makeForCurrentUser(fromPosixPermissions permissions: FilePermissions, forDir: Bool = false) throws(LowLevelError) -> Self {
        
        let processToken = try WindowsProcessToken.current()

        let tokenUserPtr = try processToken.getUser()
        let userSidPtr = tokenUserPtr.pointee.User.Sid

        let groupSidPtr = try processToken.getPrimaryGroups()
        let primaryGroupSid = groupSidPtr.pointee.PrimaryGroup

        return try .init(
            fromPosixPermissions: permissions, 
            ownerSidPtr: userSidPtr == nil ? nil : .init(unownedResource: userSidPtr!), 
            groupSidPtr: primaryGroupSid == nil ? nil : .init(unownedResource: primaryGroupSid!), 
            forDir: forDir
        )

    }


    package init(
        fromPosixPermissions permissions: FilePermissions, 
        ownerSidPtr: UnsafeUnownedResource?,
        groupSidPtr: UnsafeUnownedResource?,
        forDir: Bool = false
    ) throws(LowLevelError) {

        let ownerPermissions = Self.windowsAcePermissionBits(fromPosixPermissionBits: permissions.rawValue >> 6, forDir: forDir)
        let groupPermissions = Self.windowsAcePermissionBits(fromPosixPermissionBits: (permissions.rawValue >> 3) & 0b111, forDir: forDir)
        let othersPermissions = Self.windowsAcePermissionBits(fromPosixPermissionBits: permissions.rawValue & 0b111, forDir: forDir)

        let everyoneSidPtr = WindowsSid.everyone.psid

        var daclEntries = [] as [EXPLICIT_ACCESSW]

        do {
            // Will always be added to the DACL even if no permissions are granted.
            var entry = EXPLICIT_ACCESSW()
            entry.grfAccessMode = GRANT_ACCESS
            entry.grfAccessPermissions = ownerPermissions
            if forDir {
                entry.grfInheritance = DWORD(CONTAINER_INHERIT_ACE | OBJECT_INHERIT_ACE)
            }
            entry.Trustee.TrusteeForm = TRUSTEE_IS_SID
            entry.Trustee.TrusteeType = TRUSTEE_IS_USER
            entry.Trustee.ptstrName = ownerSidPtr?.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            daclEntries.append(entry)
        }

        if groupPermissions != 0 {
            var entry = EXPLICIT_ACCESSW()
            entry.grfAccessMode = GRANT_ACCESS
            entry.grfAccessPermissions = groupPermissions
            if forDir {
                entry.grfInheritance = DWORD(CONTAINER_INHERIT_ACE | OBJECT_INHERIT_ACE)
            }
            entry.Trustee.TrusteeForm = TRUSTEE_IS_SID
            entry.Trustee.TrusteeType = TRUSTEE_IS_GROUP
            entry.Trustee.ptstrName = groupSidPtr?.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            daclEntries.append(entry)
        }

        if othersPermissions != 0 {
            var entry = EXPLICIT_ACCESSW()
            entry.grfAccessMode = GRANT_ACCESS
            entry.grfAccessPermissions = othersPermissions
            if forDir {
                entry.grfInheritance = DWORD(CONTAINER_INHERIT_ACE | OBJECT_INHERIT_ACE)
            }
            entry.Trustee.TrusteeForm = TRUSTEE_IS_SID
            entry.Trustee.TrusteeType = TRUSTEE_IS_WELL_KNOWN_GROUP
            entry.Trustee.ptstrName = everyoneSidPtr.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            daclEntries.append(entry)
        }

        self.pacl = try daclEntries.span.withUnsafeBufferPointer { (buffer) throws(LowLevelError) in 
            try WindowsRawAcl.addEntries(.init(unownedBuffer: buffer), toAcl: nil)
        }

    }


    private static func windowsAcePermissionBits(fromPosixPermissionBits bits: CModeT, forDir: Bool = false) -> DWORD {
        var permissions = DWORD(0)
        if bits & 0b100 != 0 {
            permissions |= DWORD(FILE_READ_ATTRIBUTES | FILE_READ_EA | FILE_READ_DATA | STANDARD_RIGHTS_READ | SYNCHRONIZE)
            if forDir {
                permissions |= DWORD(FILE_LIST_DIRECTORY)
            }
        }
        if bits & 0b010 != 0 {
            permissions |= DWORD(FILE_WRITE_ATTRIBUTES | FILE_WRITE_EA | FILE_WRITE_DATA | FILE_APPEND_DATA | STANDARD_RIGHTS_WRITE | SYNCHRONIZE | DELETE)
            if forDir {
                permissions |= DWORD(FILE_ADD_FILE | FILE_ADD_SUBDIRECTORY | FILE_DELETE_CHILD)
            }
        }
        if bits & 0b001 != 0 {
            permissions |= DWORD(FILE_EXECUTE | STANDARD_RIGHTS_EXECUTE | SYNCHRONIZE)
            if forDir {
                permissions |= DWORD(FILE_TRAVERSE)
            }
        }
        return permissions
    }


    fileprivate static func addEntries(
        _ entries: UnsafeUnownedBufferPointer<EXPLICIT_ACCESSW>?, 
        toAcl acl: UnsafeUnownedPointer<ACL>?
    ) throws(LowLevelError) -> UnsafeOwnedAutoPointer<ACL> {
        var newAclPtr = nil as PACL?
        try execThrowingCFunction {
            SetEntriesInAclW(
                DWORD(entries?.count ?? 0), 
                entries?.baseAddress?.unsafeMutableCast().unsafeRawPtr, 
                acl?.unsafelyCastedMutableRawPtr,
                &newAclPtr 
            )
        } onError: { (code) throws(LowLevelError) in
            throw LowLevelError(rawSystemCode: code)!
        }
        guard let newAclPtr else {
            try LowLevelError.assertError()
        }
        return .init(owningPointer: newAclPtr, allocator: .localAlloc)
    }

}



public enum WindowsRawAclState: ~Escapable {

    case absent
    case null(defaulted: Bool)
    case present(WindowsRawAcl.View, defaulted: Bool)

    public enum StateCase: Equatable {
        case absent, null, present
    }

    public var `case`: StateCase {
        return switch self {
            case .absent:  .absent
            case .null:    .null
            case .present: .present
        }
    }

    public var value: WindowsRawAcl.View? {
        @_lifetime(copy self)
        get {
             switch self {
                case .absent, .null: return nil
                case .present(let view, _): return view
            }
        }
    }

    public var defaulted: Bool? {
        switch self {
            case .absent: return nil
            case .null(let defaulted): return defaulted
            case .present(_, let defaulted): return defaulted
        }
    }

    public var isAbsent: Bool {
        switch self {
            case .absent:         return true
            case .present, .null: return false
        }
    }

    public var isNull: Bool {
        switch self {
            case .absent, .present: return false
            case .null: return true
        }
    }

    public func detach() -> WindowsRawAcl? {
        switch self {
            case .absent, .null: return nil
            case .present(let view, _): 
                do {
                    return .init(pacl: try WindowsRawAcl.addEntries(nil, toAcl: view.pacl))
                } catch {
                    fatalError("Failed to copy ACL: \(error)")
                }
        }
    }

}



extension WindowsRawAclState {

    @_lifetime(borrow psd)
    package init(unsafeExtractingFromPSD psd: borrowing UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {
        self.init(unsafeExtractingFromPSD: psd.unownedView(), type: type)
    }


    @_lifetime(copy psd)
    package init(unsafeExtractingFromPSD psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {
        
        precondition(IsValidSecurityDescriptor(psd.unsafelyCastedMutableRawPtr), "Invalid SECURITY_DESCRIPTOR pointer")
        
        var aclPtr = nil as PACL?
        var aclPresent = false as WindowsBool
        var aclDefaulted = false as WindowsBool

        switch type {
            case .dacl: GetSecurityDescriptorDacl(psd.unsafelyCastedMutableRawPtr, &aclPresent, &aclPtr, &aclDefaulted)
            case .sacl: GetSecurityDescriptorSacl(psd.unsafelyCastedMutableRawPtr, &aclPresent, &aclPtr, &aclDefaulted)
        }

        guard aclPresent.boolValue else { 
            self = .absent
            return
        }

        switch aclPtr {
            case .some(let aclPtr): self = .present(.init(pacl: .init(unownedPointer: aclPtr)), defaulted: aclDefaulted.boolValue)
            case .none: self = .null(defaulted: aclDefaulted.boolValue)
        }

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

#endif 