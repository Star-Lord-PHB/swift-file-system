#if canImport(WinSDK)

import PlatformCLib


public struct WindowsAbsoluteSecurityDescriptor: ~Copyable {

    fileprivate(set) var psd: UnsafeOwnedMutableAutoPointer<SECURITY_DESCRIPTOR>
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

        precondition(IsValidSecurityDescriptor(psd.unsafelyCastedMutableRawPtr), "Invalid security descriptor")

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

        self.psd = psd.unsafeMutableCast()
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
                selfRelativeSd.psd.unsafelyCastedMutableRawPtr, 
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
                selfRelativeSd.psd.unsafelyCastedMutableRawPtr, 
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
        let psd = UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>.swiftAllocate(capacity: 1)
        InitializeSecurityDescriptor(psd.unsafelyCastedMutableRawPtr, DWORD(SECURITY_DESCRIPTOR_REVISION))
        self.init(psd: psd, dacl: nil, sacl: nil, owner: nil, group: nil)
    }


    public func makeSelfRelative() throws(SystemError) -> WindowsSelfRelativeSecurityDescriptor {
        let selfRelativeSd = try WindowsAPI.makeSelfRelativeSecurityDescriptor(from: psd.unownedView().immutableCast())
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
        guard psd.pointee.Dacl == dacl?.pacl.unsafelyCastedMutableRawPtr else { return false }

        let sacl = switch sacl {
            case .some(let acl): acl.view
            case .none: nil as WindowsRawAcl.View?
        }
        guard sacl?.isValid() != false else { return false }
        guard psd.pointee.Sacl == sacl?.pacl.unsafelyCastedMutableRawPtr else { return false }

        switch owner {
            case .some(let sid): 
                guard sid.isValid() else { return false }
                guard psd.pointee.Owner == sid.psid.unsafeResourcePtr else { return false }
            case .none:
                guard psd.pointee.Owner == nil else { return false }
        }

        switch group {
            case .some(let sid): 
                guard sid.isValid() else { return false }
                guard psd.pointee.Group == sid.psid.unsafeResourcePtr else { return false }
            case .none:
                guard psd.pointee.Group == nil else { return false }
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
            SetSecurityDescriptorDacl(psd.unsafeRawPtr, true, dacl?.pacl.unsafelyCastedMutableRawPtr, false)
        }
    }

    public var sacl: WindowsRawAcl? {
        _read { yield _sacl }
        _modify { 
            yield &_sacl
            precondition(sacl?.isValid() ?? true, "Invalid SACL")
            SetSecurityDescriptorSacl(psd.unsafeRawPtr, true, sacl?.pacl.unsafelyCastedMutableRawPtr, false)
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
        self.dacl = nil
    }


    public mutating func removeSacl() {
        self.sacl = nil
    }


    public mutating func removeOwner() {
        self.owner = nil
    }


    public mutating func removeGroup() {
        self.group = nil
    }


    public mutating func takeDacl() -> WindowsRawAcl? {
        return self.dacl.take()
    }


    public mutating func takeSacl() -> WindowsRawAcl? {
        return self.sacl.take()
    }

}

#endif 