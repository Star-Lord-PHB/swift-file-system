#if canImport(WinSDK)

import PlatformCLib
import struct SystemPackage.FilePermissions
import struct SystemPackage.CModeT


public struct WindowsAbsoluteSecurityDescriptor: ~Copyable {

    package fileprivate(set) var psd: UnsafeOwnedMutableAutoPointer<SECURITY_DESCRIPTOR>
    fileprivate(set) var _dacl: WindowsRawAcl?
    fileprivate(set) var _sacl: WindowsRawAcl?
    fileprivate(set) var _owner: WindowsSid?
    fileprivate(set) var _group: WindowsSid?

    package init(
        psd: consuming UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>, 
        dacl: consuming WindowsRawAcl?,
        sacl: consuming WindowsRawAcl?,
        owner: consuming WindowsSid?,
        group: consuming WindowsSid?
    ) {

        precondition(IsValidSecurityDescriptor(psd.unsafelyCastedMutableRawPtr), "Invalid security descriptor")

        var control = 0 as SECURITY_DESCRIPTOR_CONTROL
        var revision = 0 as DWORD
        precondition(
            GetSecurityDescriptorControl(psd.unsafelyCastedMutableRawPtr, &control, &revision), 
            "Failed to get security descriptor control"
        )
        precondition(
            control & .init(SE_SELF_RELATIVE) == 0, 
            "Attempting to initialize WindowsAbsoluteSecurityDescriptor using a pointer to a self-relative security descriptor"
        )

        switch dacl {
            case .some(let acl): precondition(acl.pacl.unsafeRawPtr == psd.unsafeRawPtr.pointee.Dacl, "DACL pointer mismatch")
            case .none: precondition(psd.unsafeRawPtr.pointee.Dacl == nil, "DACL pointer mismatch")
        }

        switch sacl {
            case .some(let acl): precondition(acl.pacl.unsafeRawPtr == psd.unsafeRawPtr.pointee.Sacl, "SACL pointer mismatch")
            case .none: precondition(psd.unsafeRawPtr.pointee.Sacl == nil, "SACL pointer mismatch")
        }

        switch owner {
            case .some(let sid): 
                precondition(psd.unsafeRawPtr.pointee.Owner == sid.psid.unsafeResourcePtr, "Owner SID pointer mismatch")
            case .none: precondition(psd.unsafeRawPtr.pointee.Owner == nil, "Owner SID pointer mismatch")
        }

        switch group {
            case .some(let sid): 
                precondition(psd.unsafeRawPtr.pointee.Group == sid.psid.unsafeResourcePtr, "Group SID pointer mismatch")
            case .none: precondition(psd.unsafeRawPtr.pointee.Group == nil, "Group SID pointer mismatch")
        }

        self.psd = psd.unsafeMutableCast()
        self._dacl = dacl
        self._owner = owner
        self._group = group
        self._sacl = sacl
        
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


    public func makeSelfRelative() -> WindowsSelfRelativeSecurityDescriptor {
        do {
            return try .init(converting: self)
        } catch {
            fatalError(
                """
                Unexpected failure when converting WindowsAbsoluteSecurityDescriptor to\
                WindowsSelfRelativeSecurityDescriptor: \(error). This should not happen since the\
                descriptor should have been validated. It can be a severe memory corruption issue (e.g.: the\
                pointer used to initialize this type is unexpectedly mutated by some other owner) or a bug in\
                the implementation.
                """
            )
        }
    }

    fileprivate func isValid() -> Bool {

        guard IsValidSecurityDescriptor(psd.unsafeRawPtr) else {
            return false
        }

        guard self.control.contains(.selfRelative) == false else {
            return false
        }

        let dacl = switch dacl {
            case .some(let acl): acl.view
            case .none: nil as WindowsRawAcl.View?
        }
        guard psd.pointee.Dacl == dacl?.pacl.unsafelyCastedMutableRawPtr else { return false }

        let sacl = switch sacl {
            case .some(let acl): acl.view
            case .none: nil as WindowsRawAcl.View?
        }
        guard psd.pointee.Sacl == sacl?.pacl.unsafelyCastedMutableRawPtr else { return false }

        switch owner {
            case .some(let sid): 
                guard psd.pointee.Owner == sid.psid.unsafeResourcePtr else { return false }
            case .none:
                guard psd.pointee.Owner == nil else { return false }
        }

        switch group {
            case .some(let sid): 
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
            return .make(unsafeExtractingFromPSD: psd.unownedView().immutableCast()).control
        }
        set {
            SetSecurityDescriptorControl(psd.unsafeRawPtr, .init(bitPattern: -1), newValue.rawValue)
        }
    }

    public var dacl: WindowsRawAcl? {
        _read { yield _dacl }
        _modify { 
            yield &_dacl
            SetSecurityDescriptorDacl(psd.unsafeRawPtr, true, dacl?.pacl.unsafelyCastedMutableRawPtr, false)
        }
    }

    public var sacl: WindowsRawAcl? {
        _read { yield _sacl }
        _modify { 
            yield &_sacl
            SetSecurityDescriptorSacl(psd.unsafeRawPtr, true, sacl?.pacl.unsafelyCastedMutableRawPtr, false)
        }
    }

    public var owner: WindowsSid? {
        get { _owner }
        set {
            SetSecurityDescriptorOwner(psd.unsafeRawPtr, newValue?.psid.unsafeResourcePtr, false)
            _owner = newValue
        }
    }

    public var group: WindowsSid? {
        get { _group }
        set {
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



extension WindowsAbsoluteSecurityDescriptor {

    package init(converting selfRelativeSd: borrowing WindowsSelfRelativeSecurityDescriptor) throws(SystemError) {
        try self.init(converting: selfRelativeSd.psd.unownedView())
    }


    package init(converting selfRelativeSdPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(SystemError) {
        
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
                selfRelativeSdPtr.unsafelyCastedMutableRawPtr, 
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
                selfRelativeSdPtr.unsafelyCastedMutableRawPtr, 
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


    package static func makeForCurrentUser(fromPosixPermissions posixPermissions: FilePermissions, forDir: Bool = false) throws(SystemError) -> Self {

        let processToken = try WindowsProcessToken.current()

        let tokenUserPtr = try processToken.getUser()
        let userSidPtr = tokenUserPtr.pointee.User.Sid

        let groupSidPtr = try processToken.getPrimaryGroups()
        let primaryGroupSid = groupSidPtr.pointee.PrimaryGroup

        let userSidLength = GetLengthSid(userSidPtr)
        let userSidBuffer = UnsafeOwnedRawAutoPointer.swiftAllocate(byteCount: Int(userSidLength), alignment: MemoryLayout<WCHAR>.alignment)
        try execThrowingCFunction {
            CopySid(userSidLength, userSidBuffer.unsafelyCastedMutableRawPtr, userSidPtr)
        }

        let groupSidLength = GetLengthSid(primaryGroupSid)
        let groupSidBuffer = UnsafeOwnedRawAutoPointer.swiftAllocate(byteCount: Int(groupSidLength), alignment: MemoryLayout<WCHAR>.alignment)
        try execThrowingCFunction {
            CopySid(groupSidLength, groupSidBuffer.unsafelyCastedMutableRawPtr, primaryGroupSid)
        }

        let dacl = try WindowsRawAcl(
            fromPosixPermissions: posixPermissions, 
            ownerSidPtr: userSidPtr != nil ? .init(unownedResource: userSidPtr!) : nil,
            groupSidPtr: primaryGroupSid != nil ? .init(unownedResource: primaryGroupSid!) : nil,
            forDir: forDir
        )

        let securityDescriptorPtr = UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>.swiftAllocate(capacity: 1)
        try execThrowingCFunction {
            InitializeSecurityDescriptor(securityDescriptorPtr.unsafelyCastedMutableRawPtr, DWORD(SECURITY_DESCRIPTOR_REVISION))
        }
        try execThrowingCFunction {
            SetSecurityDescriptorOwner(securityDescriptorPtr.unsafelyCastedMutableRawPtr, userSidBuffer.unsafelyCastedMutableRawPtr, false)
        }
        try execThrowingCFunction {
            SetSecurityDescriptorGroup(securityDescriptorPtr.unsafelyCastedMutableRawPtr, groupSidBuffer.unsafelyCastedMutableRawPtr, false)
        }
        try execThrowingCFunction {
            SetSecurityDescriptorDacl(securityDescriptorPtr.unsafelyCastedMutableRawPtr, true, dacl.pacl.unsafelyCastedMutableRawPtr, false)
        }

        return .init(
            psd: securityDescriptorPtr, 
            dacl: dacl, 
            sacl: nil, 
            owner: .init(psid: .init(owningResource: userSidBuffer)), 
            group: .init(psid: .init(owningResource: groupSidBuffer))
        )

    }

}

#endif 