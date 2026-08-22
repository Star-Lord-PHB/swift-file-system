#if canImport(WinSDK)

import PlatformCLib



public struct WindowsSecurityDescriptorControl: Sendable, Equatable, Hashable, ExpressibleByArrayLiteral, CustomStringConvertible {

    public let rawValue: SECURITY_DESCRIPTOR_CONTROL

    public init(unsafeRawValue: SECURITY_DESCRIPTOR_CONTROL) {
        self.rawValue = unsafeRawValue
    }
    public init(rawValue: WrittableControlFlags) {
        self.rawValue = rawValue.rawValue
    }
    public init(arrayLiteral elements: WrittableControlFlags...) {
        self.rawValue = elements.reduce(into: .zero) { $0 |= $1.rawValue }
    }

    public func contains(_ flag: ReadOnlyControlFlags) -> Bool {
        return (self.rawValue & flag.rawValue) == flag.rawValue
    }

    public mutating func insert(_ flag: WrittableControlFlags) {
        self = self.union(flag)
    }

    public mutating func formUnion(_ flag: WrittableControlFlags) {
        self = self.union(flag)
    }

    public func union(_ flag: WrittableControlFlags) -> Self {
        return .init(unsafeRawValue: self.rawValue | flag.rawValue)
    }

    public mutating func formIntersection(_ flag: WrittableControlFlags) {
        self = self.intersection(flag)
    }

    public func intersection(_ flag: WrittableControlFlags) -> Self {
        return .init(unsafeRawValue: self.rawValue & flag.rawValue)
    }

    public func removing(_ flag: WrittableControlFlags) -> Self {
        return .init(unsafeRawValue: self.rawValue & ~flag.rawValue)
    }

    public mutating func remove(_ flag: WrittableControlFlags) {
        self = self.removing(flag)
    }

    public mutating func subtract(_ flag: WrittableControlFlags) {
        self = self.removing(flag)
    }

    public func subtracting(_ flag: WrittableControlFlags) -> Self {
        return self.removing(flag)
    }

    public static var daclProtected: Self {
        .init(unsafeRawValue: .init(SE_DACL_PROTECTED))
    }
    public static var saclProtected: Self {
        .init(unsafeRawValue: .init(SE_SACL_PROTECTED))
    }
    public static var daclAutoInheritReq: Self {
        .init(unsafeRawValue: .init(SE_DACL_AUTO_INHERIT_REQ))
    }
    public static var saclAutoInheritReq: Self {
        .init(unsafeRawValue: .init(SE_SACL_AUTO_INHERIT_REQ))
    }

    @inlinable
    public var description: String {
        let allWithNameAsArray = [
            (.daclAutoInheritReq, "daclAutoInheritReq"), (.daclAutoInherited, "daclAutoInherited"), (.daclDefaulted, "daclDefaulted"), 
            (.daclPresent, "daclPresent"), (.daclProtected, "daclProtected"), (.groupDefaulted, "groupDefaulted"), 
            (.ownerDefaulted, "ownerDefaulted"), (.rmControlValid, "rmControlValid"), (.saclAutoInheritReq, "saclAutoInheritReq"), 
            (.saclAutoInherited, "saclAutoInherited"), (.saclDefaulted, "saclDefaulted"), (.saclPresent, "saclPresent"), 
            (.saclProtected, "saclProtected"), (.selfRelative, "selfRelative"),
        ] as [(ReadOnlyControlFlags, StaticString)]
        let flagDescriptions = allWithNameAsArray
            .compactMap { (flag, name) in
                self.contains(flag) ? name.description : nil
            }
            .joined(separator: ", ")
        return "0x\(String(rawValue, radix: 16)) [\(flagDescriptions)]"
    }


    public struct WrittableControlFlags: Sendable, ExpressibleByArrayLiteral, Equatable, Hashable {
        public let rawValue: SECURITY_DESCRIPTOR_CONTROL
        private init(rawValue: SECURITY_DESCRIPTOR_CONTROL) {
            self.rawValue = rawValue
        }
        public init(arrayLiteral elements: Self...) {
            var rawValue = 0 as SECURITY_DESCRIPTOR_CONTROL
            for element in elements {
                rawValue |= element.rawValue
            }
            self.rawValue = rawValue
        }
        public static func | (lhs: Self, rhs: Self) -> Self {
            return .init(rawValue: lhs.rawValue | rhs.rawValue)
        }
        public static let daclProtected: Self = .init(rawValue: .init(SE_DACL_PROTECTED))
        public static let saclProtected: Self = .init(rawValue: .init(SE_SACL_PROTECTED))
        public static let daclAutoInheritReq: Self = .init(rawValue: .init(SE_DACL_AUTO_INHERIT_REQ))
        public static let saclAutoInheritReq: Self = .init(rawValue: .init(SE_SACL_AUTO_INHERIT_REQ))
        public static let daclAutoInherited: Self = .init(rawValue: .init(SE_DACL_AUTO_INHERITED))
        public static let saclAutoInherited: Self = .init(rawValue: .init(SE_SACL_AUTO_INHERITED))
        public static var all: Self {
            [
                .daclProtected, .saclProtected, .daclAutoInheritReq, .saclAutoInheritReq,
                .daclAutoInherited, .saclAutoInherited,
            ]
        }
    }


    public struct ReadOnlyControlFlags: Sendable, OptionSet, Equatable, Hashable {
        public let rawValue: SECURITY_DESCRIPTOR_CONTROL
        public init(rawValue: SECURITY_DESCRIPTOR_CONTROL) {
            self.rawValue = rawValue
        }
        public static let daclAutoInheritReq: Self = .init(rawValue: .init(SE_DACL_AUTO_INHERIT_REQ))
        public static let daclAutoInherited: Self = .init(rawValue: .init(SE_DACL_AUTO_INHERITED))
        public static let daclDefaulted: Self = .init(rawValue: .init(SE_DACL_DEFAULTED))
        public static let daclPresent: Self = .init(rawValue: .init(SE_DACL_PRESENT))
        public static let daclProtected: Self = .init(rawValue: .init(SE_DACL_PROTECTED))
        public static let groupDefaulted: Self = .init(rawValue: .init(SE_GROUP_DEFAULTED))
        public static let ownerDefaulted: Self = .init(rawValue: .init(SE_OWNER_DEFAULTED))
        public static let rmControlValid: Self = .init(rawValue: .init(SE_RM_CONTROL_VALID))
        public static let saclAutoInheritReq: Self = .init(rawValue: .init(SE_SACL_AUTO_INHERIT_REQ))
        public static let saclAutoInherited: Self = .init(rawValue: .init(SE_SACL_AUTO_INHERITED))
        public static let saclDefaulted: Self = .init(rawValue: .init(SE_SACL_DEFAULTED))
        public static let saclPresent: Self = .init(rawValue: .init(SE_SACL_PRESENT))
        public static let saclProtected: Self = .init(rawValue: .init(SE_SACL_PROTECTED))
        public static let selfRelative: Self = .init(rawValue: .init(SE_SELF_RELATIVE))
        public static let daclUntrusted: Self = .init(rawValue: 0x0040)     // SE_DACL_UNTRUSTED
        public static let serverSecurity: Self = .init(rawValue: 0x0080)    // SE_SERVER_SECURITY
    }

}



extension WindowsSecurityDescriptorControl {

    package static func make(unsafeExtractingFromPSD psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) -> (control: Self, revision: DWORD) {
        var revision = 0 as DWORD
        var control = 0 as SECURITY_DESCRIPTOR_CONTROL
        GetSecurityDescriptorControl(psd.unsafelyCastedMutableRawPtr, &control, &revision)
        return (.init(unsafeRawValue: control), revision)
    }

}



public struct WindowsAccessMask: OptionSet, Sendable, Equatable, Hashable, CustomStringConvertible {

    @_alwaysEmitIntoClient
    public let rawValue: ACCESS_MASK

    @inlinable
    public var description: String {
        let allWithNameAsArray = [
            (.readData, "readData"), (.listDirectory, "listDirectory"), (.writeData, "writeData"),
            (.addFile, "addFile"), (.appendData, "appendData"), (.addSubdirectory, "addSubdirectory"),
            (.readExtentedAttrs, "readExtendedAttrs"), (.writeExtendedAttrs, "writeExtendedAttrs"),
            (.execute, "execute"), (.traverse, "traverse"), (.deleteChild, "deleteChild"),
            (.readAttributes, "readAttributes"), (.writeAttributes, "writeAttributes"),
            (.delete, "delete"), (.readControl, "readControl"), (.writeDAC, "writeDAC"),
            (.writeOwner, "writeOwner"), (.synchronize, "synchronize"), (.genericRead, "genericRead"), 
            (.genericWrite, "genericWrite"), (.genericExecute, "genericExecute"), (.genericAll, "genericAll"),
        ] as [(WindowsAccessMask, StaticString)]
        let flagDescriptions = allWithNameAsArray
            .compactMap { (flag, name) in
                self.contains(flag) ? name.description : nil
            }
            .joined(separator: ", ")
        return "0x\(String(rawValue, radix: 16)) [\(flagDescriptions)]"
    }

    @inlinable
    public init(rawValue: ACCESS_MASK) {
        self.rawValue = rawValue
    }

    public static let readData: WindowsAccessMask = .init(rawValue: .init(FILE_READ_DATA))
    public static let listDirectory: WindowsAccessMask = .init(rawValue: .init(FILE_LIST_DIRECTORY))
    public static let writeData: WindowsAccessMask = .init(rawValue: .init(FILE_WRITE_DATA))
    public static let addFile: WindowsAccessMask = .init(rawValue: .init(FILE_ADD_FILE))
    public static let appendData: WindowsAccessMask = .init(rawValue: .init(FILE_APPEND_DATA))
    public static let addSubdirectory: WindowsAccessMask = .init(rawValue: .init(FILE_ADD_SUBDIRECTORY))
    public static let readExtentedAttrs: WindowsAccessMask = .init(rawValue: .init(FILE_READ_EA))
    public static let writeExtendedAttrs: WindowsAccessMask = .init(rawValue: .init(FILE_WRITE_EA))
    public static let execute: WindowsAccessMask = .init(rawValue: .init(FILE_EXECUTE))
    public static let traverse: WindowsAccessMask = .init(rawValue: .init(FILE_TRAVERSE))
    public static let deleteChild: WindowsAccessMask = .init(rawValue: .init(FILE_DELETE_CHILD))
    public static let readAttributes: WindowsAccessMask = .init(rawValue: .init(FILE_READ_ATTRIBUTES))
    public static let writeAttributes: WindowsAccessMask = .init(rawValue: .init(FILE_WRITE_ATTRIBUTES))

    public static let delete: WindowsAccessMask = .init(rawValue: .init(DELETE))
    public static let readControl: WindowsAccessMask = .init(rawValue: .init(READ_CONTROL))
    public static let writeDAC: WindowsAccessMask = .init(rawValue: .init(WRITE_DAC))
    public static let writeOwner: WindowsAccessMask = .init(rawValue: .init(WRITE_OWNER))
    public static let synchronize: WindowsAccessMask = .init(rawValue: .init(SYNCHRONIZE))

    public static let genericRead: WindowsAccessMask = .init(rawValue: .init(GENERIC_READ))
    public static let genericWrite: WindowsAccessMask = .init(rawValue: .init(GENERIC_WRITE))
    public static let genericExecute: WindowsAccessMask = .init(rawValue: .init(GENERIC_EXECUTE))
    public static let genericAll: WindowsAccessMask = .init(rawValue: .init(GENERIC_ALL))

}



public struct WindowsACEFlags: OptionSet, Sendable, Equatable, Hashable, CustomStringConvertible {

    @_alwaysEmitIntoClient
    public let rawValue: BYTE

    @inlinable
    public var description: String {
        let allWithNameAsArray = [
            (.objectInherit, "objectInherit"), (.containerInherit, "containerInherit"),
            (.noPropagateInherit, "noPropagateInherit"), (.inheritOnly, "inheritOnly"),
            (.inherited, "inherited"), (.successfulAccess, "successfulAccess"), (.failedAccess, "failedAccess"),
        ] as [(WindowsACEFlags, StaticString)]
        let flagDescriptions = allWithNameAsArray
            .compactMap { (flag, name) in
                self.contains(flag) ? name.description : nil
            }
            .joined(separator: ", ")
        return "0x\(String(rawValue, radix: 16)) [\(flagDescriptions)]"
    }

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



public enum WindowsACLStateCase: Sendable, Equatable, Hashable, CustomStringConvertible {
    case absent
    case null
    case acl

    @inlinable
    public var description: String {
        switch self {
            case .absent:  "absent"
            case .null:    "null"
            case .acl:     "acl"
        }
    }
}



public enum WindowsMemoryAllocatorType {

    case globalAlloc, localAlloc, swift, malloc

    public func dealloc(pointer: UnsafeMutableRawPointer) {
        self.mappedInternalAllocatorType.dealloc(pointer: pointer)
    }

    package var mappedInternalAllocatorType: MemoryAllocatorType {
        switch self {
            case .globalAlloc:  .globalAlloc
            case .localAlloc:   .localAlloc
            case .swift:        .swift
            case .malloc:       .malloc
        }
    }

}

#endif 