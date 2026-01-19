#if canImport(WinSDK)

import SystemPackage
import WinSDK



public struct WindowsSecurityDescriptor: Sendable, Equatable, Hashable {

    public let revision: BYTE
    public let owner: String 
    public let group: String
    public let control: WindowsSecurityDescriptorControl
    public let dacl: WindowsACL?
    public let sacl: WindowsACL?

}



extension WindowsSecurityDescriptor {

    init(unsafeFromSecurityDescriptorPtr sdPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(SystemError) {

        var revision = 0 as DWORD
        var control = 0 as SECURITY_DESCRIPTOR_CONTROL

        try execThrowingCFunction {
            GetSecurityDescriptorControl(sdPtr.unsafelyCastedMutableRawPtr, &control, &revision)
        }

        self.revision = BYTE(revision)
        self.control = .init(unsafeRawValue: control)

        let (ownerSidPtr, _) = try WindowsAPI.getOwnerSid(from: sdPtr)
        self.owner = try WindowsAPI.pSidToString(sidPtr: ownerSidPtr)

        let (groupSidPtr, _) = try WindowsAPI.getGroupSid(from: sdPtr)
        self.group = try WindowsAPI.pSidToString(sidPtr: groupSidPtr)

        self.dacl = try .init(unsafeSecurityDescriptorPtr: sdPtr, type: .dacl)
        self.sacl = try .init(unsafeSecurityDescriptorPtr: sdPtr, type: .sacl)

    }

}



extension WindowsSecurityDescriptor: CustomStringConvertible {

    @inlinable
    public var description: String {
        """
        SecurityInfo(\
        revision: \(revision), \
        owner: \(owner), \
        group: \(group), \
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


        init?(unsafeSecurityDescriptorPtr sdPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>, type: WindowsACLType) throws(SystemError) {

            var aclPtr = nil as PACL?
            var aclPresent = false as WindowsBool
            var aclDefaulted = false as WindowsBool

            try execThrowingCFunction {
                switch type {
                    case .dacl: GetSecurityDescriptorDacl(sdPtr.unsafelyCastedMutableRawPtr, &aclPresent, &aclPtr, &aclDefaulted)
                    case .sacl: GetSecurityDescriptorSacl(sdPtr.unsafelyCastedMutableRawPtr, &aclPresent, &aclPtr, &aclDefaulted)
                }
            }

            guard aclPresent.boolValue, let aclPtr else {
                return nil
            }

            self.revision = aclPtr.pointee.AclRevision
            self.isDefaulted = aclDefaulted.boolValue

            self.aceList = try (0 ..< aclPtr.pointee.AceCount).map { (i) throws(SystemError) in 
                var acePtr = nil as LPVOID?
                try execThrowingCFunction {
                    GetAce(aclPtr, DWORD(i), &acePtr)
                }
                guard let acePtr else {
                    try SystemError.assertError()
                }
                return try WindowsACE(unsafeFromACEPtr: .init(unownedPointer: acePtr))
            }

            self.type = type

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


        init(unsafeFromACEPtr acePtr: UnsafeUnownedRawPointer) throws(SystemError) {
            
            let headerPtr = acePtr.bindMemory(to: ACE_HEADER.self, capacity: 1)

            self.type = WindowsACEType(rawValue: headerPtr.pointee.AceType)
            self.flags = WindowsACEFlags(rawValue: headerPtr.pointee.AceFlags)
            self.size = headerPtr.pointee.AceSize

            switch type {

                case .allow: do {
                    let allowAcePtr = acePtr.bindMemory(to: ACCESS_ALLOWED_ACE.self, capacity: 1)
                    self.mask = WindowsAccessMask(rawValue: allowAcePtr.pointee.Mask)
                    self.sid = try WindowsAPI.pSidToString(sidPtr: .init(unownedResource: allowAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .deny: do {
                    let denyAcePtr = acePtr.bindMemory(to: ACCESS_DENIED_ACE.self, capacity: 1)
                    self.mask = WindowsAccessMask(rawValue: denyAcePtr.pointee.Mask)
                    self.sid = try WindowsAPI.pSidToString(sidPtr: .init(unownedResource: denyAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .audit: do {
                    let auditAcePtr = acePtr.bindMemory(to: SYSTEM_AUDIT_ACE.self, capacity: 1)
                    self.mask = WindowsAccessMask(rawValue: auditAcePtr.pointee.Mask)
                    self.sid = try WindowsAPI.pSidToString(sidPtr: .init(unownedResource: auditAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .alarm: do {
                    let alarmAcePtr = acePtr.bindMemory(to: SYSTEM_ALARM_ACE.self, capacity: 1)
                    self.mask = WindowsAccessMask(rawValue: alarmAcePtr.pointee.Mask)
                    self.sid = try WindowsAPI.pSidToString(sidPtr: .init(unownedResource: alarmAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }

            }

        }

    }

}

#endif
