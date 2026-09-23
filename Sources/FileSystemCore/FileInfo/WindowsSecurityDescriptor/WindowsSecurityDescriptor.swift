#if canImport(WinSDK)

import SystemPackage
import WinSDK



/// Fully parsed representation of a Windows Security Descriptor.
public struct WindowsSecurityDescriptor: Sendable, Equatable, Hashable {

    /// The revision number of the security descriptor
    public let revision: BYTE
    /// The owner SID
    public let owner: String?
    /// The group SID
    public let group: String?
    /// The control flags
    public let control: WindowsSecurityDescriptorControl
    /// The DACL if present
    public let dacl: WindowsACL?
    /// The SACL if present
    public let sacl: WindowsACL?

}



extension WindowsSecurityDescriptor {

    package init(unsafeFromSecurityDescriptorPtr sdPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) {

        let (control, revision) = WindowsSecurityDescriptorControl.make(unsafeExtractingFromPSD: sdPtr)

        self.revision = BYTE(revision)
        self.control = control

        if let (ownerSidView, _) = WindowsSid.View.make(unsafeExtractingOwnerFromPSD: sdPtr) {
            self.owner = ownerSidView.string
        } else {
            self.owner = nil
        }
        
        if let (groupSidView, _) = WindowsSid.View.make(unsafeExtractingGroupFromPSD: sdPtr) {
            self.group = groupSidView.string
        } else {
            self.group = nil
        }

        self.dacl = .init(unsafeSecurityDescriptorPtr: sdPtr, type: .dacl)
        self.sacl = .init(unsafeSecurityDescriptorPtr: sdPtr, type: .sacl)

    }

}



extension WindowsSecurityDescriptor: CustomStringConvertible {

    @inlinable
    public var description: String {
        """
        SecurityInfo(\
        revision: \(revision), \
        owner: \(owner.map { $0.description } ?? "nil"), \
        group: \(group.map { $0.description } ?? "nil"), \
        control: \(control), \
        dacl: \(dacl.map{ $0.description } ?? "nil"), \
        sacl: \(sacl.map{ $0.description } ?? "nil"))
        """
    }

}



extension WindowsSecurityDescriptor {

    /// The fully parsed representation of a Windows ACL
    public struct WindowsACL: Sendable, Equatable, Hashable, CustomStringConvertible {

        /// The revision number of the ACL
        public let revision: BYTE
        /// The list of ACEs in the ACL
        public let aceList: [WindowsACE]
        /// Whether the ACL is defaulted
        public let isDefaulted: Bool
        /// The type of the ACL (DACL or SACL)
        public let type: WindowsACLType

        @inlinable
        public var description: String {
            "Windows\(type)(revision: \(revision), isDefaulted: \(isDefaulted), aceList: \(aceList))"
        }

    }


    /// The fully parsed representation of a Windows ACE
    public struct WindowsACE: Sendable, Equatable, Hashable, CustomStringConvertible {

        /// The type of the ACE
        public let type: WindowsACEType
        /// The flags of the ACE
        public let flags: WindowsACEFlags
        /// The size in bytes of the ACE
        public let size: WORD
        /// The access mask of the ACE
        public let mask: WindowsAccessMask
        /// The SID that the ACE applies to
        public let sid: String

        @inlinable
        public var description: String {
            "ACE(\(type), flags: \(flags), size: \(size), mask: \(mask), sid: \(sid))"
        }

    }

}



extension WindowsSecurityDescriptor.WindowsACL {

    package init?(unsafeSecurityDescriptorPtr sdPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {

        let aclState = WindowsRawAclStateView(unsafeExtractingFromPSD: sdPtr, type: type)

        guard case let .acl(aclView, defaulted) = aclState else { return nil }

        self.revision = aclView.revision
        self.isDefaulted = defaulted

        self.aceList = aclView.map { aceView in 
            .init(
                type: aceView.type, 
                flags: aceView.flags, 
                size: aceView.size, 
                mask: aceView.permission.mask, 
                sid: aceView.permission.sid.string
            )
        }

        self.type = type

    }

}

#endif
