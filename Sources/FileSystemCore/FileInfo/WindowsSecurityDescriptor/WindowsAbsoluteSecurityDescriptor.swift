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
        owner: WindowsSid?,
        group: WindowsSid?
    ) {

        self.psd = psd.unsafeMutableCast()
        self._dacl = dacl
        self._owner = owner
        self._group = group
        self._sacl = sacl

        preconditionValid()
        
    }

    public init(
        unsafeOwningSdPtr: PSECURITY_DESCRIPTOR, 
        allocator: WindowsMemoryAllocatorType,
        pdacl: consuming WindowsRawAcl? = nil,
        psacl: consuming WindowsRawAcl? = nil,
        owner: WindowsSid? = nil,
        group: WindowsSid? = nil
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

    public init(
        control: WindowsSecurityDescriptorControl? = nil,
        dacl: consuming WindowsRawAcl? = nil,
        sacl: consuming WindowsRawAcl? = nil,
        owner: WindowsSid? = nil,
        group: WindowsSid? = nil
    ) {
        let psd = UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>.swiftAllocate(capacity: 1)
        InitializeSecurityDescriptor(psd.unsafelyCastedMutableRawPtr, DWORD(SECURITY_DESCRIPTOR_REVISION))
        if let control {
            // SetSecurityDescriptorControl rejects the whole call (without changing
            // anything) unless both parameters stay within the writable control bits.
            let writableBits = WindowsSecurityDescriptorControl.WrittableControlFlags.all.rawValue
            SetSecurityDescriptorControl(
                psd.unsafelyCastedMutableRawPtr,
                writableBits,
                control.rawValue & writableBits
            )
        }
        SetSecurityDescriptorDacl(psd.unsafelyCastedMutableRawPtr, true, dacl?.pacl.unsafelyCastedMutableRawPtr, false)
        SetSecurityDescriptorSacl(psd.unsafelyCastedMutableRawPtr, true, sacl?.pacl.unsafelyCastedMutableRawPtr, false)
        SetSecurityDescriptorOwner(psd.unsafelyCastedMutableRawPtr, owner?.psid.unsafeResourcePtr, false)
        SetSecurityDescriptorGroup(psd.unsafelyCastedMutableRawPtr, group?.psid.unsafeResourcePtr, false)
        self.init(psd: psd, dacl: dacl, sacl: sacl, owner: owner, group: group)
    }

    public var view: WindowsSecurityDescriptorView {
        .init(psd: psd.unownedView().immutableCast())
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

    fileprivate func preconditionValid(file: StaticString = #file, line: UInt = #line) {

        precondition(IsValidSecurityDescriptor(psd.unsafeRawPtr), "Invalid security descriptor", file: file, line: line)

        precondition(self.control.contains(.selfRelative) == false, "SECURITY_DESCRIPTOR is self-relative, expected absolute", file: file, line: line)

        let dacl = switch dacl {
            case .some(let acl): acl.view
            case .none: nil as WindowsRawAcl.View?
        }
        precondition(psd.pointee.Dacl == dacl?.pacl.unsafelyCastedMutableRawPtr, "DACL pointer mismatch", file: file, line: line)

        let sacl = switch sacl {
            case .some(let acl): acl.view
            case .none: nil as WindowsRawAcl.View?
        }
        precondition(psd.pointee.Sacl == sacl?.pacl.unsafelyCastedMutableRawPtr, "SACL pointer mismatch", file: file, line: line)

        let sidPtr = switch owner {
            case .some(let sid): sid.psid.unsafeResourcePtr
            case .none: nil as UnsafeMutableRawPointer?
        }
        precondition(psd.pointee.Owner == sidPtr, "Owner SID pointer mismatch", file: file, line: line)

        let groupSidPtr = switch group {
            case .some(let sid): sid.psid.unsafeResourcePtr
            case .none: nil as UnsafeMutableRawPointer?
        }
        precondition(psd.pointee.Group == groupSidPtr, "Group SID pointer mismatch", file: file, line: line)

    }

    public func withUnsafeSdPtr<R: ~Copyable, E: Error>(_ body: (PSECURITY_DESCRIPTOR) throws(E) -> R) throws(E) -> R {
        let result = try body(psd.unsafeRawPtr)
        preconditionValid()
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
            // See `init(control:...)`: both parameters must stay within the writable
            // control bits, or the call fails as a whole without changing anything.
            let writableBits = WindowsSecurityDescriptorControl.WrittableControlFlags.all.rawValue
            SetSecurityDescriptorControl(
                psd.unsafeRawPtr,
                writableBits,
                newValue.rawValue & writableBits
            )
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


    public mutating func addDaclEntries(_ entries: WindowsExplicitAccessArray) {
        if var dacl = self.dacl.take() {
            dacl.addEntries(entries)
            self.dacl = .some(dacl)
        } else {
            self.dacl = .init(entries: entries)
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

    package init(converting selfRelativeSd: borrowing WindowsSelfRelativeSecurityDescriptor) throws(LowLevelError) {
        try self.init(converting: selfRelativeSd.psd.unownedView())
    }


    package init(converting selfRelativeSdPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(LowLevelError) {
        
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
            throw .init(rawSystemCode: errorCode)!
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


    package static func makeForCurrentUser(fromPosixPermissions posixPermissions: FilePermissions, forDir: Bool = false) throws(LowLevelError) -> Self {

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