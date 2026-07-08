#if canImport(WinSDK)

import SystemPackage
import WinSDK



public struct WindowsSecurityDescriptor: Sendable, Equatable, Hashable {

    public let revision: BYTE
    public let owner: String?
    public let group: String?
    public let control: WindowsSecurityDescriptorControl
    public let dacl: WindowsACL?
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

    public struct WindowsACL: Sendable, Equatable, Hashable, CustomStringConvertible {

        public let revision: BYTE
        public let aceList: [WindowsACE]
        public let isDefaulted: Bool
        public let type: WindowsACLType

        @inlinable
        public var description: String {
            "Windows\(type)(revision: \(revision), isDefaulted: \(isDefaulted), aceList: \(aceList))"
        }

    }


    public struct WindowsACE: Sendable, Equatable, Hashable, CustomStringConvertible {

        public let type: WindowsACEType
        public let flags: WindowsACEFlags
        public let size: WORD
        public let mask: WindowsAccessMask
        public let sid: String

        @inlinable
        public var description: String {
            "ACE(\(type), flags: \(flags), size: \(size), mask: \(mask), sid: \(sid))"
        }

    }

}



extension WindowsSecurityDescriptor.WindowsACL {

    package init?(unsafeSecurityDescriptorPtr sdPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) {

        let aclState = WindowsRawAclState(unsafeExtractingFromPSD: sdPtr, type: type)

        guard case let .present(aclView, defaulted) = aclState else { return nil }

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
