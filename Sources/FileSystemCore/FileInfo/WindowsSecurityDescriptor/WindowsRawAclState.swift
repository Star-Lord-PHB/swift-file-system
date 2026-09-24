#if canImport(WinSDK)

import PlatformCLib


/// The state of an Windows ACL slot (DACL or SACL) of an absolute security descriptor, owning the ACL when one is present.
public enum WindowsRawAclState: ~Copyable, Sendable {

    /// The ACL is not specified
    /// 
    /// When creating a new file, this state means that the file will inherit the ACL from its parent directory.
    case absent
    /// The ACL is specified but is NULL, granting everyone full access for a DACL
    case null
    /// The ACL is specified and is present
    case acl(WindowsRawAcl)

    /// The case of the ACL state, without the associated value.
    public var `case`: WindowsACLStateCase {
        return switch self {
            case .absent:  .absent
            case .null:    .null
            case .acl:     .acl
        }
    }

    /// The unowned view to the ACL value, if present.
    public var value: WindowsRawAcl.View? {
        @_lifetime(borrow self)
        get {
            switch self {
                case .absent: return nil
                case .null: return nil
                case .acl(let acl): return acl.view
            }
        }
    }

    /// Whether the ACL state is `.absent`.
    public var isAbsent: Bool {
        switch self {
            case .absent:  return true
            case .null:    return false
            case .acl:     return false
        }
    }

    /// Whether the ACL state is `.null`.
    public var isNull: Bool {
        switch self {
            case .absent:  return false
            case .null:    return true
            case .acl:     return false
        }
    }

    /// Update the ACL by adding new rules described by the given ``WindowsExplicitAccessArray``, and create a new 
    /// one if not exist.
    public mutating func addEntries(_ entries: WindowsExplicitAccessArray) {
        switch consume self {
            case .acl(var acl):
                acl.addEntries(entries)
                self = .acl(acl)
            case .absent:
                self = .acl(.init(entries: entries))
            case .null:
                self = .acl(.init(entries: entries))
        }
    }

    /// Takes the ACL value out of an `.acl` state, leaving `newState` behind
    /// 
    /// The state always becomes `newState` even when there was no ACL to take.
    public mutating func take(leaving newState: consuming WindowsRawAclState) -> WindowsRawAcl? {
        switch consume self {
            case .acl(let acl):
                self = newState
                return acl
            case .absent:
                self = newState
                return nil
            case .null:
                self = newState
                return nil
        }
    }

}



/// An unowned view of a Windows ACL slot (DACL or SACL) as stored in a security descriptor
/// 
/// This type is normally used for accessing the ACL contained in a self-relative security descriptor read from a 
/// file system item, so it includes additional information compared to the ``WindowsRawAclState``, such as whether 
/// the ACL is defaulted.
public enum WindowsRawAclStateView: ~Escapable, Sendable {

    /// The ACL is not specified
    case absent
    /// The ACL is specified but is NULL, granting everyone full access for a DACL
    case null(defaulted: Bool)
    /// The ACL is specified and is present
    case acl(WindowsRawAcl.View, defaulted: Bool)

    /// The case of the ACL state, without the associated value.
    public var `case`: WindowsACLStateCase {
        return switch self {
            case .absent:  .absent
            case .null:    .null
            case .acl:     .acl
        }
    }

    /// The unowned view to the ACL value, if present.
    public var value: WindowsRawAcl.View? {
        @_lifetime(copy self)
        get {
             switch self {
                case .absent, .null: return nil
                case .acl(let view, _): return view
            }
        }
    }

    /// Whether the ACL is defaulted, if present.
    public var defaulted: Bool? {
        switch self {
            case .absent: return nil
            case .null(let defaulted): return defaulted
            case .acl(_, let defaulted): return defaulted
        }
    }

    /// Whether the ACL state is `.absent`.
    public var isAbsent: Bool {
        switch self {
            case .absent:     return true
            case .acl, .null: return false
        }
    }

    /// Whether the ACL state is `.null`.
    public var isNull: Bool {
        switch self {
            case .absent, .acl: return false
            case .null: return true
        }
    }

    /// Copies the unowned view into a standalone ``WindowsRawAclState`` while dropping the `defaulted` flag.
    public func detach() -> WindowsRawAclState {
        switch self {
            case .absent: return .absent
            case .null: return .null
            case .acl(let view, _): return .acl(view.detach())
        }
    }

}



extension WindowsRawAclStateView {

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
            case .some(let aclPtr): self = .acl(.init(pacl: .init(unownedPointer: aclPtr)), defaulted: aclDefaulted.boolValue)
            case .none: self = .null(defaulted: aclDefaulted.boolValue)
        }

    }

}


#endif
