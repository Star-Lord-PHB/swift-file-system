#if canImport(WinSDK)

import PlatformCLib


public struct WindowsAbsoluteSecurityDescriptor: ~Copyable {

    fileprivate(set) var psd: UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>
    fileprivate(set) var _dacl: WindowsRawAcl?
    fileprivate(set) var _sacl: WindowsRawAcl?
    fileprivate(set) var _owner: WindowsSid?
    fileprivate(set) var _group: WindowsSid?

    init(
        psd: consuming UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>, 
        dacl: consuming WindowsRawAcl?,
        sacl: consuming WindowsRawAcl?,
        owner: consuming WindowsSid?,
        group: consuming WindowsSid?
    ) {

        precondition(IsValidSecurityDescriptor(psd.unsafeRawPtr), "Invalid security descriptor")

        switch dacl {
            case .some(let acl): 
                precondition(acl.isValid(), "Invalid DACL")
                precondition(acl.pacl.unsafeRawPtr == psd.unsafeRawPtr.pointee.Dacl, "DACL pointer mismatch")
            case .none: precondition(psd.unsafeRawPtr.pointee.Dacl == nil, "DACL pointer mismatch")
        }

        switch sacl {
            case .some(let acl): 
                precondition(acl.isValid(), "Invalid SACL")
                precondition(acl.pacl.unsafeRawPtr == psd.unsafeRawPtr.pointee.Sacl, "SACL pointer mismatch")
            case .none: precondition(psd.unsafeRawPtr.pointee.Sacl == nil, "SACL pointer mismatch")
        }

        switch owner {
            case .some(let sid): 
                precondition(sid.isValid(), "Invalid owner SID")
                precondition(psd.unsafeRawPtr.pointee.Owner == sid.psid.unsafeResourcePtr, "Owner SID pointer mismatch")
            case .none: precondition(psd.unsafeRawPtr.pointee.Owner == nil, "Owner SID pointer mismatch")
        }

        switch group {
            case .some(let sid): 
                precondition(sid.isValid(), "Invalid group SID")
                precondition(psd.unsafeRawPtr.pointee.Group == sid.psid.unsafeResourcePtr, "Group SID pointer mismatch")
            case .none: precondition(psd.unsafeRawPtr.pointee.Group == nil, "Group SID pointer mismatch")
        }

        self.psd = psd
        self._dacl = dacl
        self._owner = owner
        self._group = group
        self._sacl = sacl
        
    }

    init(converting selfRelativeSd: borrowing WindowsSelfRelativeSecurityDescriptor) throws(SystemError) {

        var psd = nil as UnsafeMutablePointer<SECURITY_DESCRIPTOR>?
        var pdacl = nil as UnsafeMutablePointer<ACL>?
        var psacl = nil as UnsafeMutablePointer<ACL>?
        var owner = nil as UnsafeMutablePointer<SID>?
        var group = nil as UnsafeMutablePointer<SID>?

        var sdSize = 0 as DWORD
        var daclSize = 0 as DWORD
        var saclSize = 0 as DWORD
        var ownerSize = 0 as DWORD
        var groupSize = 0 as DWORD

        precondition(
            MakeAbsoluteSD(
                selfRelativeSd.psd.unsafeRawPtr, 
                psd, &sdSize, 
                pdacl, &daclSize, 
                psacl, &saclSize, 
                owner, &ownerSize, 
                group, &groupSize
            ) == false,
            "MakeAbsoluteSD should fail due to insufficient buffer for the first call"
        )

        let errorCode = GetLastError()
        guard errorCode == ERROR_INSUFFICIENT_BUFFER else {
            throw SystemError(code: errorCode)!
        }

        psd = UnsafeMutablePointer<SECURITY_DESCRIPTOR>.allocate(capacity: Int(sdSize))

        if daclSize > 0 {
            pdacl = UnsafeMutablePointer<ACL>.allocate(capacity: Int(daclSize))
        }

        if saclSize > 0 {
            psacl = UnsafeMutablePointer<ACL>.allocate(capacity: Int(saclSize))
        }

        if ownerSize > 0 {
            owner = UnsafeMutablePointer<SID>.allocate(capacity: Int(ownerSize))
        }

        if groupSize > 0 {
            group = UnsafeMutablePointer<SID>.allocate(capacity: Int(groupSize))
        }

        try execThrowingCFunction {
            MakeAbsoluteSD(
                selfRelativeSd.psd.unsafeRawPtr, 
                psd!, &sdSize, 
                pdacl, &daclSize, psacl, &saclSize, 
                owner, &ownerSize, group, &groupSize
            )
        }

        self.init(
            psd: .init(owningPointer: psd!, allocator: .swift), 
            dacl: pdacl.map { .init(pacl: .init(owningPointer: $0, allocator: .swift)) }, 
            sacl: psacl.map { .init(pacl: .init(owningPointer: $0, allocator: .swift)) }, 
            owner: owner.map { .init(psid: .init(owningResource: $0, freeingFunc: { $0.deallocate() })) }, 
            group: group.map { .init(psid: .init(owningResource: $0, freeingFunc: { $0.deallocate() })) }
        )

    }

    public init(
        unsafeOwningSdPtr: PSECURITY_DESCRIPTOR, 
        allocator: WindowsMemoryAllocatorType,
        pdacl: consuming WindowsRawAcl? = nil,
        psacl: consuming WindowsRawAcl? = nil,
        owner: consuming WindowsSid? = nil,
        group: consuming WindowsSid? = nil
    ) {
        self.init(
            psd: .init(
                owningPointer: unsafeOwningSdPtr.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self), 
                allocator: allocator.mappedInternalAllocatorType
            ), 
            dacl: pdacl, 
            sacl: psacl, 
            owner: owner, 
            group: group
        )
    }

    public init() {
        let psd = UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>(owningPointer: .allocate(capacity: 1), allocator: .swift)
        InitializeSecurityDescriptor(psd.unsafeRawPtr, DWORD(SECURITY_DESCRIPTOR_REVISION))
        self.init(psd: psd, dacl: nil, sacl: nil, owner: nil, group: nil)
    }


    public func makeSelfRelative() throws(SystemError) -> WindowsSelfRelativeSecurityDescriptor {
        let selfRelativeSd = try WindowsAPI.makeSelfRelativeSecurityDescriptor(from: psd.unownedView())
        return .init(psd: selfRelativeSd)
    }

    public func isValid() -> Bool {

        guard IsValidSecurityDescriptor(psd.unsafeRawPtr) else {
            return false
        }

        let dacl = switch dacl {
            case .some(let acl): acl.view
            case .none: nil as WindowsRawAcl.View?
        }
        guard dacl?.isValid() != false else { return false }
        guard psd.unsafeRawPtr.pointee.Dacl == dacl?.pacl.unsafeRawPtr else { return false }

        let sacl = switch sacl {
            case .some(let acl): acl.view
            case .none: nil as WindowsRawAcl.View?
        }
        guard sacl?.isValid() != false else { return false }
        guard psd.unsafeRawPtr.pointee.Sacl == sacl?.pacl.unsafeRawPtr else { return false }

        switch owner {
            case .some(let sid): 
                guard sid.isValid() else { return false }
                guard psd.unsafeRawPtr.pointee.Owner == sid.psid.unsafeResourcePtr else { return false }
            case .none:
                guard psd.unsafeRawPtr.pointee.Owner == nil else { return false }
        }

        switch group {
            case .some(let sid): 
                guard sid.isValid() else { return false }
                guard psd.unsafeRawPtr.pointee.Group == sid.psid.unsafeResourcePtr else { return false }
            case .none:
                guard psd.unsafeRawPtr.pointee.Group == nil else { return false }
        }

        return true

    }

    public func withUnsafeSdPtr<R: ~Copyable, E: Error>(_ body: (PSECURITY_DESCRIPTOR) throws(E) -> R) throws(E) -> R {
        let result = try body(psd.unsafeRawPtr)
        precondition(self.isValid(), "SECURITY_DESCRIPTOR pointer corrupted")
        return result
    }

}



extension WindowsAbsoluteSecurityDescriptor {

    public var revision: DWORD {
        var revision = 0 as DWORD
        var control = 0 as SECURITY_DESCRIPTOR_CONTROL
        GetSecurityDescriptorControl(psd.unsafeRawPtr, &control, &revision)
        return revision
    }

    public var control: WindowsSecurityDescriptorControl {
        get {
            var revision = 0 as DWORD
            var control = 0 as SECURITY_DESCRIPTOR_CONTROL
            GetSecurityDescriptorControl(psd.unsafeRawPtr, &control, &revision)
            return .init(unsafeRawValue: control)
        }
        set {
            SetSecurityDescriptorControl(psd.unsafeRawPtr, .init(bitPattern: -1), newValue.rawValue)
        }
    }

    public var dacl: WindowsRawAcl? {
        _read { yield _dacl }
        _modify { 
            yield &_dacl
            precondition(dacl?.isValid() ?? true, "Invalid DACL")
            SetSecurityDescriptorDacl(psd.unsafeRawPtr, true, dacl?.pacl.unsafeRawPtr, false)
        }
    }

    public var sacl: WindowsRawAcl? {
        _read { yield _sacl }
        _modify { 
            yield &_sacl
            precondition(sacl?.isValid() ?? true, "Invalid SACL")
            SetSecurityDescriptorSacl(psd.unsafeRawPtr, true, sacl?.pacl.unsafeRawPtr, false)
        }
    }

    public var owner: WindowsSid? {
        get { _owner }
        set {
            precondition(newValue?.isValid() ?? true, "Invalid owner SID")
            SetSecurityDescriptorOwner(psd.unsafeRawPtr, newValue?.psid.unsafeResourcePtr, false)
            _owner = newValue
        }
    }

    public var group: WindowsSid? {
        get { _group }
        set {
            precondition(newValue?.isValid() ?? true, "Invalid group SID")
            SetSecurityDescriptorGroup(psd.unsafeRawPtr, newValue?.psid.unsafeResourcePtr, false)
            _group = newValue
        }
    }


    public mutating func removeDacl() {
        self.dacl = .init()
    }


    public mutating func removeSacl() {
        self.sacl = .init()
    }


    public mutating func removeOwner() {
        self.owner = nil
    }


    public mutating func removeGroup() {
        self.group = nil
    }

}



public struct ExplicitAccess {
    public var permission: ACCESS_MASK
    public var accessMode: AccessMode
    public var inheritance: Inheritance
    public var trustee: RawTrustee

    public var unsafeRawExplicitAccess: EXPLICIT_ACCESSW {
        var ea = EXPLICIT_ACCESSW()
        ea.grfAccessPermissions = permission
        ea.grfAccessMode = accessMode.rawAccessMode
        ea.grfInheritance = inheritance.rawValue
        ea.Trustee = TRUSTEE_W(
            pMultipleTrustee: nil,
            MultipleTrusteeOperation: NO_MULTIPLE_TRUSTEE,
            TrusteeForm: TRUSTEE_IS_SID,
            TrusteeType: trustee.type.rawTrusteeType,
            ptstrName: trustee.sid.psid.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
        )
        return ea
    }
}



public enum AccessMode: ACCESS_MODE.RawValue {
    case notUsed, grantAccess, setAccess, denyAccess, revokeAccess
    case setAuditSuccess, setAuditFailure
    public var rawAccessMode: ACCESS_MODE { .init(rawValue: self.rawValue) }
}



public struct Inheritance: Sendable, OptionSet {

    public let rawValue: DWORD

    public init(rawValue: DWORD) {
        self.rawValue = rawValue
    }

    public static let containerInherit: Inheritance = .init(rawValue: DWORD(CONTAINER_INHERIT_ACE))
    public static let inheritNoPropagate: Inheritance = .init(rawValue: DWORD(INHERIT_NO_PROPAGATE))
    public static let inheritOnly: Inheritance = .init(rawValue: DWORD(INHERIT_ONLY))
    public static let inheritOnlyAce: Inheritance = .init(rawValue: DWORD(INHERIT_ONLY_ACE))
    public static let noInheritance: Inheritance = .init(rawValue: DWORD(NO_INHERITANCE))
    public static let noPropagateInheritAce: Inheritance = .init(rawValue: DWORD(NO_PROPAGATE_INHERIT_ACE))
    public static let objectInheritAce: Inheritance = .init(rawValue: DWORD(OBJECT_INHERIT_ACE))
    public static let subContainerAndObjectInherit: Inheritance = .init(rawValue: DWORD(SUB_CONTAINERS_AND_OBJECTS_INHERIT))
    public static let subContainerOnlyInherit: Inheritance = .init(rawValue: DWORD(SUB_CONTAINERS_ONLY_INHERIT))
    public static let subObjectOnlyInherit: Inheritance = .init(rawValue: DWORD(SUB_OBJECTS_ONLY_INHERIT))

}



public struct RawTrustee {
    public var sid: WindowsSid
    public var type: TrusteeType
    public init(sid: WindowsSid, type: TrusteeType) {
        self.sid = sid
        self.type = type
    }
}



public enum TrusteeType: TRUSTEE_TYPE.RawValue {
    case unknown, user, group, domain, alias, wellKnownGroup, deleted, invalid, computer
    public var rawTrusteeType: TRUSTEE_TYPE { .init(rawValue: self.rawValue) }
}

#endif 