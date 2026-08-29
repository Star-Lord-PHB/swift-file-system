#if canImport(WinSDK)

import PlatformCLib


/// The state of an ACL slot (DACL or SACL) of an absolute security descriptor, owning the
/// ACL when one is present.
///
/// The three cases are deliberately explicit: `.null` (an ACL that is present but empty at
/// the pointer level, granting everyone full access for a DACL) and `.absent` (no ACL is
/// specified; at creation time the system falls back to inheritance or the token default)
/// are equivalent for access checks but behave differently when the descriptor is used to
/// create an item or written back, so neither is a "default" the API silently assumes.
public enum WindowsRawAclState: ~Copyable {

    case absent
    case null
    case acl(WindowsRawAcl)

    public var `case`: WindowsACLStateCase {
        return switch self {
            case .absent:  .absent
            case .null:    .null
            case .acl:     .acl
        }
    }

    // NOTE: multi-pattern case labels (`case .absent, .null:`) over non-Copyable values are
    // not implemented by the compiler yet, so the switches below spell every case out.

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

    public var isAbsent: Bool {
        switch self {
            case .absent:  return true
            case .null:    return false
            case .acl:     return false
        }
    }

    public var isNull: Bool {
        switch self {
            case .absent:  return false
            case .null:    return true
            case .acl:     return false
        }
    }

    /// Merges the entries into the ACL, creating one when the state is `.absent` or `.null`.
    ///
    /// Adding entries to a `.null` state replaces "everyone has full access" with a DACL
    /// containing only the given entries, matching how `SetEntriesInAclW` treats a NULL ACL.
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

    /// Takes the ACL out of an `.acl` state, leaving `newState` behind; the state always
    /// becomes `newState` even when there was no ACL to take.
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



/// A borrowed decode of an ACL slot (DACL or SACL) as stored in a security descriptor,
/// including the wire-level `defaulted` flag that the owning ``WindowsRawAclState`` does
/// not carry.
public enum WindowsRawAclStateView: ~Escapable, Sendable {

    case absent
    case null(defaulted: Bool)
    case acl(WindowsRawAcl.View, defaulted: Bool)

    public var `case`: WindowsACLStateCase {
        return switch self {
            case .absent:  .absent
            case .null:    .null
            case .acl:     .acl
        }
    }

    public var value: WindowsRawAcl.View? {
        @_lifetime(copy self)
        get {
             switch self {
                case .absent, .null: return nil
                case .acl(let view, _): return view
            }
        }
    }

    public var defaulted: Bool? {
        switch self {
            case .absent: return nil
            case .null(let defaulted): return defaulted
            case .acl(_, let defaulted): return defaulted
        }
    }

    public var isAbsent: Bool {
        switch self {
            case .absent:     return true
            case .acl, .null: return false
        }
    }

    public var isNull: Bool {
        switch self {
            case .absent, .acl: return false
            case .null: return true
        }
    }

    /// Copies the borrowed state into an owning ``WindowsRawAclState``, preserving all
    /// three cases; the `defaulted` flag is dropped.
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
