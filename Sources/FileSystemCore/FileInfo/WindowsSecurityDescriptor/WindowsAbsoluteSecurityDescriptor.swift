#if canImport(WinSDK)

import PlatformCLib
import struct SystemPackage.FilePermissions
import struct SystemPackage.CModeT


/// Wrapper for Windows SECURITY_DESCRIPTOR that is absolute
public struct WindowsAbsoluteSecurityDescriptor: ~Copyable {

    package fileprivate(set) var psd: UnsafeOwnedMutableAutoPointer<SECURITY_DESCRIPTOR>
    fileprivate(set) var _dacl: WindowsRawAclState
    fileprivate(set) var _sacl: WindowsRawAclState
    fileprivate(set) var _owner: WindowsSid?
    fileprivate(set) var _group: WindowsSid?

    package init(
        psd: consuming UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>,
        dacl: consuming WindowsRawAclState,
        sacl: consuming WindowsRawAclState,
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

    /// Create a new absolute security descriptor from an existing pointer to a SECURITY_DESCRIPTOR and its components.
    /// 
    /// - Parameters:
    ///   - sdPtr: A pointer to a SECURITY_DESCRIPTOR, whose ownership is transferred to this new instance.
    ///   - allocator: The allocator used to manage the memory of the SECURITY_DESCRIPTOR.
    ///   - dacl: The DACL associated with the SECURITY_DESCRIPTOR pointer.
    ///   - sacl: The SACL associated with the SECURITY_DESCRIPTOR pointer.
    ///   - owner: The owner SID associated with the SECURITY_DESCRIPTOR pointer.
    ///   - group: The group SID associated with the SECURITY_DESCRIPTOR pointer.
    /// 
    /// - Attention: The components must match the member of the SECURITY_DESCRIPTOR and the descriptor must be absolute.
    public init(
        unsafeOwningSdPtr sdPtr: PSECURITY_DESCRIPTOR,
        allocator: WindowsMemoryAllocatorType,
        dacl: consuming WindowsRawAclState = .absent,
        sacl: consuming WindowsRawAclState = .absent,
        owner: WindowsSid? = nil,
        group: WindowsSid? = nil
    ) {
        self.init(
            psd: .init(
                owningPointer: sdPtr.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self),
                allocator: allocator.mappedInternalAllocatorType
            ),
            dacl: dacl,
            sacl: sacl,
            owner: owner,
            group: group
        )
    }

    /// Creates a new absolute security descriptor with the given components.
    /// 
    /// - Parameters:
    ///   - control: The control flags for the security descriptor.
    ///   - dacl: The DACL associated with the security descriptor.
    ///   - sacl: The SACL associated with the security descriptor.
    ///   - owner: The owner SID associated with the security descriptor.
    ///   - group: The group SID associated with the security descriptor.
    public init(
        control: WindowsSecurityDescriptorControl? = nil,
        dacl: consuming WindowsRawAclState = .absent,
        sacl: consuming WindowsRawAclState = .absent,
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
        Self.unsafeApplyAclState(dacl, to: psd.unsafelyCastedMutableRawPtr, type: .dacl)
        Self.unsafeApplyAclState(sacl, to: psd.unsafelyCastedMutableRawPtr, type: .sacl)
        SetSecurityDescriptorOwner(psd.unsafelyCastedMutableRawPtr, owner?.psid.unsafeResourcePtr, false)
        SetSecurityDescriptorGroup(psd.unsafelyCastedMutableRawPtr, group?.psid.unsafeResourcePtr, false)
        self.init(psd: psd, dacl: dacl, sacl: sacl, owner: owner, group: group)
    }

    fileprivate static func unsafeApplyAclState(
        _ state: borrowing WindowsRawAclState,
        to psdPtr: PSECURITY_DESCRIPTOR,
        type: WindowsACLType
    ) {
        switch type {
            case .dacl:
                switch state {
                    case .absent:           SetSecurityDescriptorDacl(psdPtr, false, nil, false)
                    case .null:             SetSecurityDescriptorDacl(psdPtr, true, nil, false)
                    case .acl(let acl):     SetSecurityDescriptorDacl(psdPtr, true, acl.pacl.unsafelyCastedMutableRawPtr, false)
                }
            case .sacl:
                switch state {
                    case .absent:           SetSecurityDescriptorSacl(psdPtr, false, nil, false)
                    case .null:             SetSecurityDescriptorSacl(psdPtr, true, nil, false)
                    case .acl(let acl):     SetSecurityDescriptorSacl(psdPtr, true, acl.pacl.unsafelyCastedMutableRawPtr, false)
                }
        }
    }

    /// Get an unowned view of the security descriptor
    public var view: WindowsSecurityDescriptorView {
        .init(psd: psd.unownedView().immutableCast())
    }

    /// Create a self-relative copy of the absolute security descriptor.
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

        let control = self.control

        // For .absent only the control bit is checked: clearing the present flag leaves the
        // ACL pointer field untouched, so a stale pointer may legitimately remain behind it.
        switch _dacl {
            case .absent:
                precondition(control.contains(.daclPresent) == false, "DACL state mismatch, expected absent", file: file, line: line)
            case .null:
                precondition(control.contains(.daclPresent), "DACL state mismatch, expected null", file: file, line: line)
                precondition(psd.pointee.Dacl == nil, "DACL pointer mismatch, expected null", file: file, line: line)
            case .acl(let acl):
                precondition(control.contains(.daclPresent), "DACL state mismatch, expected present", file: file, line: line)
                precondition(psd.pointee.Dacl == acl.pacl.unsafelyCastedMutableRawPtr, "DACL pointer mismatch", file: file, line: line)
        }

        switch _sacl {
            case .absent:
                precondition(control.contains(.saclPresent) == false, "SACL state mismatch, expected absent", file: file, line: line)
            case .null:
                precondition(control.contains(.saclPresent), "SACL state mismatch, expected null", file: file, line: line)
                precondition(psd.pointee.Sacl == nil, "SACL pointer mismatch, expected null", file: file, line: line)
            case .acl(let acl):
                precondition(control.contains(.saclPresent), "SACL state mismatch, expected present", file: file, line: line)
                precondition(psd.pointee.Sacl == acl.pacl.unsafelyCastedMutableRawPtr, "SACL pointer mismatch", file: file, line: line)
        }

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

    /// Access the underlying SECURITY_DESCRIPTOR pointer within a closure.
    /// 
    /// - Parameter body: A closure for accessing the SECURITY_DESCRIPTOR pointer.
    /// 
    /// - Warning: Do not return or store the pointer outside the closure.
    public func withUnsafeSdPtr<R: ~Copyable, E: Error>(_ body: (PSECURITY_DESCRIPTOR) throws(E) -> R) throws(E) -> R {
        let result = try body(psd.unsafeRawPtr)
        preconditionValid()
        return result
    }

}



extension WindowsAbsoluteSecurityDescriptor {

    /// The revision number of the security descriptor.
    public var revision: DWORD {
        var revision = 0 as DWORD
        var control = 0 as SECURITY_DESCRIPTOR_CONTROL
        GetSecurityDescriptorControl(psd.unsafeRawPtr, &control, &revision)
        return revision
    }

    /// The control flags of the security descriptor.
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

    /// The DACL state.
    public var dacl: WindowsRawAclState {
        _read { yield _dacl }
        _modify {
            yield &_dacl
            Self.unsafeApplyAclState(_dacl, to: psd.unsafeRawPtr, type: .dacl)
        }
    }

    /// The SACL state.
    public var sacl: WindowsRawAclState {
        _read { yield _sacl }
        _modify {
            yield &_sacl
            Self.unsafeApplyAclState(_sacl, to: psd.unsafeRawPtr, type: .sacl)
        }
    }

    /// The owner SID, if present.
    public var owner: WindowsSid? {
        get { _owner }
        set {
            SetSecurityDescriptorOwner(psd.unsafeRawPtr, newValue?.psid.unsafeResourcePtr, false)
            _owner = newValue
        }
    }

    /// The group SID, if present.
    public var group: WindowsSid? {
        get { _group }
        set {
            SetSecurityDescriptorGroup(psd.unsafeRawPtr, newValue?.psid.unsafeResourcePtr, false)
            _group = newValue
        }
    }


    /// Removes the owner SID from the security descriptor.
    public mutating func removeOwner() {
        self.owner = nil
    }


    /// Removes the group SID from the security descriptor.
    public mutating func removeGroup() {
        self.group = nil
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

        // MakeAbsoluteSD preserves the present bits, so when it hands back no ACL pointer
        // the control word tells a present-but-null ACL apart from an absent one.
        let sourceControl = WindowsSecurityDescriptorControl.make(unsafeExtractingFromPSD: selfRelativeSdPtr).control

        let dacl = switch pdacl {
            case .some(let pdacl): .acl(.init(pacl: .init(owningPointer: pdacl, allocator: .swift)))
            case .none: sourceControl.contains(.daclPresent) ? .null : .absent
        } as WindowsRawAclState

        let sacl = switch psacl {
            case .some(let psacl): .acl(.init(pacl: .init(owningPointer: psacl, allocator: .swift)))
            case .none: sourceControl.contains(.saclPresent) ? .null : .absent
        } as WindowsRawAclState

        self.init(
            psd: .init(owningPointer: psd!, allocator: .swift),
            dacl: dacl,
            sacl: sacl,
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
            dacl: .acl(dacl),
            sacl: .absent,
            owner: .init(psid: .init(owningResource: userSidBuffer)),
            group: .init(psid: .init(owningResource: groupSidBuffer))
        )

    }

}

#endif 
