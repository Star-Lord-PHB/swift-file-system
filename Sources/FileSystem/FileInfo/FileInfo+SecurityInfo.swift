import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
#endif


extension FileInfo {

    public struct PlatformSecurityInfo: Sendable, Equatable, Hashable {
        
        #if canImport(WinSDK)

        public let revision: BYTE
        public let owner: String 
        public let group: String
        public let control: SECURITY_DESCRIPTOR_CONTROL
        public let dacl: WindowsACL?
        public let sacl: WindowsACL?

        #else 

        public let permission: FilePermissions
        public let uid: UInt32
        public let gid: UInt32

        #endif // canImport(WinSDK)

    }

}



extension FileInfo.PlatformSecurityInfo {

    #if canImport(WinSDK)

    @inlinable
    public var description: String {
        "SecurityInfo(revision: \(revision), owner: \(owner), group: \(group), control: \(control), dacl: \(String(describing: dacl)), sacl: \(String(describing: sacl)))"
    }

    #else 

    @inlinable
    public var description: String {
        "SecurityInfo(permission: \(permission), uid: \(uid), gid: \(gid))"
    }
    
    #endif

}



#if canImport(WinSDK)
extension FileInfo.PlatformSecurityInfo {

    init(unsafeFromSecurityDescriptorPtr sdPtr: PSECURITY_DESCRIPTOR) throws(SystemError) {

        var revision = 0 as DWORD
        var control = 0 as SECURITY_DESCRIPTOR_CONTROL

        try execThrowingCFunction {
            GetSecurityDescriptorControl(sdPtr, &control, &revision)
        }

        self.revision = BYTE(revision)
        self.control = control

        var ownerSidPtr = nil as PSID?
        var ownerDefaulted = false as WindowsBool
        try execThrowingCFunction {
            GetSecurityDescriptorOwner(sdPtr, &ownerSidPtr, &ownerDefaulted)
        }
        guard let ownerSidPtr else {
            try SystemError.assertError()
        }

        self.owner = try WindowsAPI.pSidToString(sidPtr: ownerSidPtr)

        var groupSidPtr = nil as PSID?
        var groupDefaulted = false as WindowsBool
        try execThrowingCFunction {
            GetSecurityDescriptorGroup(sdPtr, &groupSidPtr, &groupDefaulted)
        }
        guard let groupSidPtr else {
            try SystemError.assertError()
        }

        self.group = try WindowsAPI.pSidToString(sidPtr: groupSidPtr)

        self.dacl = try .init(unsafeSecurityDescriptorPtr: sdPtr, type: .dacl)
        self.sacl = try .init(unsafeSecurityDescriptorPtr: sdPtr, type: .sacl)

    }

}


extension FileInfo.PlatformSecurityInfo {

    public struct WindowsACL: Sendable, Equatable, Hashable, CustomStringConvertible {

        public let revision: BYTE
        public let aceList: [WindowsACE]
        public let isDefaulted: Bool
        public let type: WindowsACLType

        @inlinable
        public var description: String {
            "Windows\(type)(revision: \(revision), isDefaulted: \(isDefaulted), aceList: \(aceList))"
        }


        init?(unsafeSecurityDescriptorPtr sdPtr: PSECURITY_DESCRIPTOR, type: WindowsACLType) throws(SystemError) {

            var aclPtr = nil as PACL?
            var aclPresent = false as WindowsBool
            var aclDefaulted = false as WindowsBool

            try execThrowingCFunction {
                switch type {
                    case .dacl: GetSecurityDescriptorDacl(sdPtr, &aclPresent, &aclPtr, &aclDefaulted)
                    case .sacl: GetSecurityDescriptorSacl(sdPtr, &aclPresent, &aclPtr, &aclDefaulted)
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
                return try WindowsACE(unsafeFromACEPtr: acePtr)
            }

            self.type = type

        }

    }


    public enum WindowsACLType: Sendable, Equatable, Hashable, CustomStringConvertible {
        case dacl
        case sacl

        @inlinable
        public var description: String {
            switch self {
                case .dacl: "DACL"
                case .sacl: "SACL"
            }
        }
    }


    public struct WindowsACE: Sendable, Equatable, Hashable, CustomStringConvertible {

        public let type: WindowsACEType
        public let flags: WindowsACEFlags
        public let size: WORD
        public let mask: WindowsACEAccessMask
        public let sid: String

        @inlinable
        public var description: String {
            "ACE(\(type), flags: \(flags), size: \(size), mask: \(mask), sid: \(sid))"
        }


        init(unsafeFromACEPtr acePtr: LPVOID) throws(SystemError) {
            
            let headerPtr = acePtr.bindMemory(to: ACE_HEADER.self, capacity: 1)

            self.type = WindowsACEType(rawValue: headerPtr.pointee.AceType)
            self.flags = WindowsACEFlags(rawValue: headerPtr.pointee.AceFlags)
            self.size = headerPtr.pointee.AceSize

            switch type {

                case .allow: do {
                    let allowAcePtr = acePtr.bindMemory(to: ACCESS_ALLOWED_ACE.self, capacity: 1)
                    self.mask = WindowsACEAccessMask(rawValue: allowAcePtr.pointee.Mask)
                    self.sid = try withUnsafeMutablePointer(to: &allowAcePtr.pointee.SidStart) { (ptr) throws(SystemError) in 
                        try WindowsAPI.pSidToString(sidPtr: .init(ptr))
                    }
                }
                case .deny: do {
                    let denyAcePtr = acePtr.bindMemory(to: ACCESS_DENIED_ACE.self, capacity: 1)
                    self.mask = WindowsACEAccessMask(rawValue: denyAcePtr.pointee.Mask)
                    self.sid = try withUnsafeMutablePointer(to: &denyAcePtr.pointee.SidStart) { (ptr) throws(SystemError) in 
                        try WindowsAPI.pSidToString(sidPtr: .init(ptr))
                    }
                }
                case .audit: do {
                    let auditAcePtr = acePtr.bindMemory(to: SYSTEM_AUDIT_ACE.self, capacity: 1)
                    self.mask = WindowsACEAccessMask(rawValue: auditAcePtr.pointee.Mask)
                    self.sid = try withUnsafeMutablePointer(to: &auditAcePtr.pointee.SidStart) { (ptr) throws(SystemError) in 
                        try WindowsAPI.pSidToString(sidPtr: .init(ptr))
                    }
                }
                case .alarm: do {
                    let alarmAcePtr = acePtr.bindMemory(to: SYSTEM_ALARM_ACE.self, capacity: 1)
                    self.mask = WindowsACEAccessMask(rawValue: alarmAcePtr.pointee.Mask)
                    self.sid = try withUnsafeMutablePointer(to: &alarmAcePtr.pointee.SidStart) { (ptr) throws(SystemError) in 
                        try WindowsAPI.pSidToString(sidPtr: .init(ptr))
                    }
                }

            }

        }

    }

}


extension FileInfo.PlatformSecurityInfo {

    public enum WindowsACEType: BYTE, Sendable, Equatable, Hashable, CustomStringConvertible {

        case allow
        case deny
        case audit
        case alarm

        @inlinable
        public init(rawValue: BYTE) {
            switch rawValue {
                case .init(ACCESS_ALLOWED_ACE_TYPE):  self = .allow
                case .init(ACCESS_DENIED_ACE_TYPE):   self = .deny
                case .init(SYSTEM_AUDIT_ACE_TYPE):    self = .audit
                case .init(SYSTEM_ALARM_ACE_TYPE):    self = .alarm
                default:                              fatalError("Unsupported ACE type \(rawValue) for files")
            }
        }

        @inlinable
        public var rawValue: BYTE {
            switch self {
                case .allow:   return .init(ACCESS_ALLOWED_ACE_TYPE)
                case .deny:    return .init(ACCESS_DENIED_ACE_TYPE)
                case .audit:   return .init(SYSTEM_AUDIT_ACE_TYPE)
                case .alarm:   return .init(SYSTEM_ALARM_ACE_TYPE)
            }
        }

        @inlinable
        public var description: String {
            switch self {
                case .allow:   "allow"
                case .deny:    "deny"
                case .audit:   "audit"
                case .alarm:   "alarm"
            }
        }

    }


    public struct WindowsACEFlags: OptionSet, Sendable, Equatable, Hashable {

        @_alwaysEmitIntoClient
        public let rawValue: BYTE

        @inlinable
        public init(rawValue: BYTE) {
            self.rawValue = rawValue
        }

        public static let objectInherit: WindowsACEFlags = .init(rawValue: .init(OBJECT_INHERIT_ACE))
        public static let containerInherit: WindowsACEFlags = .init(rawValue: .init(CONTAINER_INHERIT_ACE))
        public static let noPropagateInherit: WindowsACEFlags = .init(rawValue: .init(NO_PROPAGATE_INHERIT_ACE))
        public static let inheritOnly: WindowsACEFlags = .init(rawValue: .init(INHERIT_ONLY_ACE))
        public static let inherited: WindowsACEFlags = .init(rawValue: .init(INHERITED_ACE))
        public static let successfulAccess: WindowsACEFlags = .init(rawValue: .init(SUCCESSFUL_ACCESS_ACE_FLAG))
        public static let failedAccess: WindowsACEFlags = .init(rawValue: .init(FAILED_ACCESS_ACE_FLAG))

    }


    public struct WindowsACEAccessMask: OptionSet, Sendable, Equatable, Hashable {

        @_alwaysEmitIntoClient
        public let rawValue: ACCESS_MASK

        @inlinable
        public init(rawValue: ACCESS_MASK) {
            self.rawValue = rawValue
        }

        public static let readData: WindowsACEAccessMask = .init(rawValue: .init(FILE_READ_DATA))
        public static let listDirectory: WindowsACEAccessMask = .init(rawValue: .init(FILE_LIST_DIRECTORY))
        public static let writeData: WindowsACEAccessMask = .init(rawValue: .init(FILE_WRITE_DATA))
        public static let addFile: WindowsACEAccessMask = .init(rawValue: .init(FILE_ADD_FILE))
        public static let appendData: WindowsACEAccessMask = .init(rawValue: .init(FILE_APPEND_DATA))
        public static let addSubdirectory: WindowsACEAccessMask = .init(rawValue: .init(FILE_ADD_SUBDIRECTORY))
        public static let readExtentedAttrs: WindowsACEAccessMask = .init(rawValue: .init(FILE_READ_EA))
        public static let writeExtendedAttrs: WindowsACEAccessMask = .init(rawValue: .init(FILE_WRITE_EA))
        public static let execute: WindowsACEAccessMask = .init(rawValue: .init(FILE_EXECUTE))
        public static let traverse: WindowsACEAccessMask = .init(rawValue: .init(FILE_TRAVERSE))
        public static let deleteChild: WindowsACEAccessMask = .init(rawValue: .init(FILE_DELETE_CHILD))
        public static let readAttributes: WindowsACEAccessMask = .init(rawValue: .init(FILE_READ_ATTRIBUTES))
        public static let writeAttributes: WindowsACEAccessMask = .init(rawValue: .init(FILE_WRITE_ATTRIBUTES))

        public static let delete: WindowsACEAccessMask = .init(rawValue: .init(DELETE))
        public static let readControl: WindowsACEAccessMask = .init(rawValue: .init(READ_CONTROL))
        public static let writeDAC: WindowsACEAccessMask = .init(rawValue: .init(WRITE_DAC))
        public static let writeOwner: WindowsACEAccessMask = .init(rawValue: .init(WRITE_OWNER))
        public static let synchronize: WindowsACEAccessMask = .init(rawValue: .init(SYNCHRONIZE))

        public static let genericRead: WindowsACEAccessMask = .init(rawValue: .init(GENERIC_READ))
        public static let genericWrite: WindowsACEAccessMask = .init(rawValue: .init(GENERIC_WRITE))
        public static let genericExecute: WindowsACEAccessMask = .init(rawValue: .init(GENERIC_EXECUTE))
        public static let genericAll: WindowsACEAccessMask = .init(rawValue: .init(GENERIC_ALL))

    }

}
#endif