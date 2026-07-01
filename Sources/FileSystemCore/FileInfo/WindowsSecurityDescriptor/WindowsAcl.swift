#if canImport(WinSDK)

import PlatformCLib
import struct SystemPackage.FilePermissions
import struct SystemPackage.CModeT


public protocol WindowRawAclProtocol: ~Copyable, ~Escapable {
    func withUnsafeNullablePACL<R: ~Copyable, E: Error>(_ operation: (PACL?) throws(E) -> R) throws(E) -> R
}



extension WindowRawAclProtocol where Self: ~Copyable & ~Escapable {

    public var revision: BYTE {
        return self.withUnsafeNullablePACL { pacl in 
            pacl?.pointee.AclRevision ?? BYTE(ACL_REVISION)
        }
    }

    public var isNull: Bool {
        return self.withUnsafeNullablePACL { pacl in pacl == nil }
    }

    public var aceCount: WORD {
        return self.withUnsafeNullablePACL { pacl in 
            pacl?.pointee.AceCount ?? 0
        }
    }

    public subscript(_ index: Int) -> WindowsRawAceSnapshotView {
        @_lifetime(borrow self)
        get {
            precondition(index >= 0 && index < Int(self.aceCount), "Index out of bounds")
            let acePtr = self.withUnsafeNullablePACL { pacl in 
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
    }

    public func forEach<E: Error>(_ body: (WindowsRawAceSnapshotView) throws(E) -> Void) throws(E) {
        for i in 0 ..< Int(self.aceCount) {
            try body(self[i])
        }
    }


    public func map<T, E: Error>(_ transform: (WindowsRawAceSnapshotView) throws(E) -> T) throws(E) -> [T] {
        var results = [T]()
        for i in 0 ..< Int(self.aceCount) {
            let result = try transform(self[i])
            results.append(result)
        }
        return results
    }


    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, WindowsRawAceSnapshotView) throws(E) -> T
    ) throws(E) -> T {
        var result = initialResult
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            result = try nextPartialResult(result, aceView)
        }
        return result
    }

    public func compactMap<T, E: Error>(_ transform: (WindowsRawAceSnapshotView) throws(E) -> T?) throws(E) -> [T] {
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
        _ updateAccumulatingResult: (inout T, WindowsRawAceSnapshotView) throws(E) -> Void
    ) throws(E) -> T {
        var result = initialResult
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            try updateAccumulatingResult(&result, aceView)
        }
        return result
    }

    public var first: WindowsRawAceSnapshotView? {
        @_lifetime(borrow self)
        get {
            guard self.aceCount > 0 else { return nil }
            return self[0]
        }
    }

    
    @_lifetime(borrow self)
    public func first(where predicate: (WindowsRawAceSnapshotView) throws -> Bool) rethrows -> WindowsRawAceSnapshotView? {
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            if try predicate(aceView) {
                return aceView
            }
        }
        return nil
    }

}



public protocol WindowsRawAclNotNullableAclProtocol: ~Copyable, ~Escapable, WindowRawAclProtocol {
    func withUnsafePACL<R: ~Copyable, E: Error>(_ operation: (PACL) throws(E) -> R) throws(E) -> R
}



extension WindowsRawAclNotNullableAclProtocol where Self: ~Copyable & ~Escapable {

    public func withUnsafeNullablePACL<R: ~Copyable, E: Error>(_ operation: (PACL?) throws(E) -> R) throws(E) -> R {
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

    public struct View: ~Escapable, WindowsRawAclNotNullableAclProtocol {

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

    package static func makeForCurrentUser(fromPosixPermissions permissions: FilePermissions, forDir: Bool = false) throws(SystemError) -> Self {
        
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
    ) throws(SystemError) {

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

        self.pacl = try daclEntries.span.withUnsafeBufferPointer { (buffer) throws(SystemError) in 
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
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<ACL> {
        var newAclPtr = nil as PACL?
        try execThrowingCFunction {
            SetEntriesInAclW(
                DWORD(entries?.count ?? 0), 
                entries?.baseAddress?.unsafeMutableCast().unsafeRawPtr, 
                acl?.unsafelyCastedMutableRawPtr,
                &newAclPtr 
            )
        } onError: { (code) throws(SystemError) in
            throw SystemError(code: code)!
        }
        guard let newAclPtr else {
            try SystemError.assertError()
        }
        return .init(owningPointer: newAclPtr, allocator: .localAlloc)
    }

}



public struct WindowsRawAclSnapshotView: ~Escapable, WindowRawAclProtocol {

    package let pacl: UnsafeUnownedPointer<ACL>?
    public let aclDefaulted: Bool

    @_lifetime(copy pacl)
    package init(pacl: UnsafeUnownedPointer<ACL>?, aclDefaulted: Bool) {
        precondition(IsValidAcl(pacl?.unsafelyCastedMutableRawPtr), "Invalid ACL pointer")
        self.pacl = pacl
        self.aclDefaulted = aclDefaulted
    }

    @_lifetime(immortal)
    public init(unsafeBorrowingAclPtr: PACL, aclDefaulted: Bool) {
        self.pacl = .init(unownedPointer: unsafeBorrowingAclPtr)
        self.aclDefaulted = aclDefaulted
    }

    public func withUnsafeNullablePACL<R: ~Copyable, E: Error>(_ operation: (PACL?) throws(E) -> R) throws(E) -> R {
        return switch self.pacl {
            case .some(let pacl): try operation(pacl.unsafelyCastedMutableRawPtr)
            case .none: try operation(nil)
        }
    }

    public func detach() -> WindowsRawAcl? {
        do {
            return .init(pacl: try WindowsRawAcl.addEntries(nil, toAcl: self.pacl))
        } catch {
            fatalError("Failed to copy ACL: \(error)")
        }
    }

}



extension WindowsRawAclSnapshotView {

    @_lifetime(borrow psd)
    package init?(unsafeExtractingFromPSD psd: borrowing UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {
        self.init(unsafeExtractingFromPSD: psd.unownedView(), type: type)
    }


    @_lifetime(copy psd)
    package init?(unsafeExtractingFromPSD psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {
        
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

}



public struct WindowsRawAceSnapshotView: ~Escapable {

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