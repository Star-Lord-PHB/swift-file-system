#if canImport(WinSDK)

import PlatformCLib



/// The control flags of a Windows Security Descriptor
public struct WindowsSecurityDescriptorControl: Sendable, Equatable, Hashable, ExpressibleByArrayLiteral, CustomStringConvertible {

    /// The native SECURITY_DESCRIPTOR_CONTROL value
    public let rawValue: SECURITY_DESCRIPTOR_CONTROL

    /// Creates from the native SECURITY_DESCRIPTOR_CONTROL value
    public init(unsafeRawValue: SECURITY_DESCRIPTOR_CONTROL) {
        self.rawValue = unsafeRawValue
    }
    /// Creates from a set of modificable flags as WrittableControlFlags
    public init(rawValue: WrittableControlFlags) {
        self.rawValue = rawValue.rawValue
    }
    public init(arrayLiteral elements: WrittableControlFlags...) {
        self.rawValue = elements.reduce(into: .zero) { $0 |= $1.rawValue }
    }

    /// Whether the control flags contains the given flags
    public func contains(_ flag: ReadOnlyControlFlags) -> Bool {
        return (self.rawValue & flag.rawValue) == flag.rawValue
    }

    /// Inserts the given flags into the control flags
    public mutating func insert(_ flag: WrittableControlFlags) {
        self = self.union(flag)
    }

    /// Union the given flags into the control flags
    public mutating func formUnion(_ flag: WrittableControlFlags) {
        self = self.union(flag)
    }

    /// Creates a new instance that is the union of the current flags and the given flags
    public func union(_ flag: WrittableControlFlags) -> Self {
        return .init(unsafeRawValue: self.rawValue | flag.rawValue)
    }

    /// Intersects the control flags with the given flags
    public mutating func formIntersection(_ flag: WrittableControlFlags) {
        self = self.intersection(flag)
    }

    /// Creates a new instance that is the intersection of the current flags and the given flags
    public func intersection(_ flag: WrittableControlFlags) -> Self {
        return .init(unsafeRawValue: self.rawValue & flag.rawValue)
    }

    /// Creates a new instance by subtracting the given flags from the current flags
    public func removing(_ flag: WrittableControlFlags) -> Self {
        return .init(unsafeRawValue: self.rawValue & ~flag.rawValue)
    }

    /// Removes the given flags from the control flags
    public mutating func remove(_ flag: WrittableControlFlags) {
        self = self.removing(flag)
    }

    /// Removes the given flags from the control flags
    public mutating func subtract(_ flag: WrittableControlFlags) {
        self = self.removing(flag)
    }

    /// Create a new instance by subtracting the given flags from the current flags
    public func subtracting(_ flag: WrittableControlFlags) -> Self {
        return self.removing(flag)
    }

    /// `SE_DACL_PROTECTED`
    public static var daclProtected: Self { [.daclProtected] }
    /// `SE_SACL_PROTECTED`
    public static var saclProtected: Self { [.saclProtected] }
    /// `SE_DACL_AUTO_INHERIT_REQ`
    public static var daclAutoInheritReq: Self { [.daclAutoInheritReq] }
    /// `SE_SACL_AUTO_INHERIT_REQ`
    public static var saclAutoInheritReq: Self { [.saclAutoInheritReq] }
    /// `SE_DACL_AUTO_INHERITED`
    public static var daclAutoInherited: Self { [.daclAutoInherited] }
    /// `SE_SACL_AUTO_INHERITED`
    public static var saclAutoInherited: Self { [.saclAutoInherited] }

    @inlinable
    public var description: String {
        let allWithNameAsArray = [
            (.daclAutoInheritReq, "daclAutoInheritReq"), (.daclAutoInherited, "daclAutoInherited"), (.daclDefaulted, "daclDefaulted"), 
            (.daclPresent, "daclPresent"), (.daclProtected, "daclProtected"), (.groupDefaulted, "groupDefaulted"), 
            (.ownerDefaulted, "ownerDefaulted"), (.rmControlValid, "rmControlValid"), (.saclAutoInheritReq, "saclAutoInheritReq"), 
            (.saclAutoInherited, "saclAutoInherited"), (.saclDefaulted, "saclDefaulted"), (.saclPresent, "saclPresent"), 
            (.saclProtected, "saclProtected"), (.selfRelative, "selfRelative"), (.daclUntrusted, "daclUntrusted"),
            (.serverSecurity, "serverSecurity"),
        ] as [(ReadOnlyControlFlags, StaticString)]
        let flagDescriptions = allWithNameAsArray
            .compactMap { (flag, name) in
                self.contains(flag) ? name.description : nil
            }
            .joined(separator: ", ")
        return "0x\(String(rawValue, radix: 16)) [\(flagDescriptions)]"
    }


    /// The control flags of a Windows Security Descriptor that can be modified
    public struct WrittableControlFlags: Sendable, ExpressibleByArrayLiteral, Equatable, Hashable {
        /// The native SECURITY_DESCRIPTOR_CONTROL value
        public let rawValue: SECURITY_DESCRIPTOR_CONTROL
        private init(rawValue: SECURITY_DESCRIPTOR_CONTROL) {
            self.rawValue = rawValue
        }
        /// Creates a new instance by combining the given flags
        public init(arrayLiteral elements: Self...) {
            var rawValue = 0 as SECURITY_DESCRIPTOR_CONTROL
            for element in elements {
                rawValue |= element.rawValue
            }
            self.rawValue = rawValue
        }
        /// Creates a new instance by combining two sets of flags
        public static func | (lhs: Self, rhs: Self) -> Self {
            return .init(rawValue: lhs.rawValue | rhs.rawValue)
        }
        /// `SE_DACL_PROTECTED`
        public static let daclProtected: Self = .init(rawValue: .init(SE_DACL_PROTECTED))
        /// `SE_SACL_PROTECTED`
        public static let saclProtected: Self = .init(rawValue: .init(SE_SACL_PROTECTED))
        /// `SE_DACL_AUTO_INHERIT_REQ`
        public static let daclAutoInheritReq: Self = .init(rawValue: .init(SE_DACL_AUTO_INHERIT_REQ))
        /// `SE_SACL_AUTO_INHERIT_REQ`
        public static let saclAutoInheritReq: Self = .init(rawValue: .init(SE_SACL_AUTO_INHERIT_REQ))
        /// `SE_DACL_AUTO_INHERITED`
        public static let daclAutoInherited: Self = .init(rawValue: .init(SE_DACL_AUTO_INHERITED))
        /// `SE_SACL_AUTO_INHERITED`
        public static let saclAutoInherited: Self = .init(rawValue: .init(SE_SACL_AUTO_INHERITED))
        /// All flags that can be modified
        public static var all: Self {
            [
                .daclProtected, .saclProtected, .daclAutoInheritReq, .saclAutoInheritReq,
                .daclAutoInherited, .saclAutoInherited,
            ]
        }
    }


    /// The control flags of a Windows Security Descriptor that can be read
    public struct ReadOnlyControlFlags: Sendable, OptionSet, Equatable, Hashable {
        /// The native SECURITY_DESCRIPTOR_CONTROL value
        public let rawValue: SECURITY_DESCRIPTOR_CONTROL
        /// Creates from the native SECURITY_DESCRIPTOR_CONTROL value
        public init(rawValue: SECURITY_DESCRIPTOR_CONTROL) {
            self.rawValue = rawValue
        }
        /// `SE_DACL_AUTO_INHERIT_REQ`
        public static let daclAutoInheritReq: Self = .init(rawValue: .init(SE_DACL_AUTO_INHERIT_REQ))
        /// `SE_DACL_AUTO_INHERITED`
        public static let daclAutoInherited: Self = .init(rawValue: .init(SE_DACL_AUTO_INHERITED))
        /// `SE_DACL_DEFAULTED`
        public static let daclDefaulted: Self = .init(rawValue: .init(SE_DACL_DEFAULTED))
        /// `SE_DACL_PRESENT`
        public static let daclPresent: Self = .init(rawValue: .init(SE_DACL_PRESENT))
        /// `SE_DACL_PROTECTED`
        public static let daclProtected: Self = .init(rawValue: .init(SE_DACL_PROTECTED))
        /// `SE_GROUP_DEFAULTED`
        public static let groupDefaulted: Self = .init(rawValue: .init(SE_GROUP_DEFAULTED))
        /// `SE_OWNER_DEFAULTED`
        public static let ownerDefaulted: Self = .init(rawValue: .init(SE_OWNER_DEFAULTED))
        /// `SE_RM_CONTROL_VALID`
        public static let rmControlValid: Self = .init(rawValue: .init(SE_RM_CONTROL_VALID))
        /// `SE_SACL_AUTO_INHERIT_REQ`
        public static let saclAutoInheritReq: Self = .init(rawValue: .init(SE_SACL_AUTO_INHERIT_REQ))
        /// `SE_SACL_AUTO_INHERITED`
        public static let saclAutoInherited: Self = .init(rawValue: .init(SE_SACL_AUTO_INHERITED))
        /// `SE_SACL_DEFAULTED`
        public static let saclDefaulted: Self = .init(rawValue: .init(SE_SACL_DEFAULTED))
        /// `SE_SACL_PRESENT`
        public static let saclPresent: Self = .init(rawValue: .init(SE_SACL_PRESENT))
        /// `SE_SACL_PROTECTED`
        public static let saclProtected: Self = .init(rawValue: .init(SE_SACL_PROTECTED))
        /// `SE_SELF_RELATIVE`
        public static let selfRelative: Self = .init(rawValue: .init(SE_SELF_RELATIVE))
        /// `SE_DACL_UNTRUSTED`
        public static let daclUntrusted: Self = .init(rawValue: 0x0040)     // SE_DACL_UNTRUSTED
        /// `SE_SERVER_SECURITY`
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



/// The flags of a Windows ACE
public struct WindowsACEFlags: OptionSet, Sendable, Equatable, Hashable, CustomStringConvertible {

    /// The native ACE flags value
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

    /// Creates from the native ACE flags value
    @inlinable
    public init(rawValue: BYTE) {
        self.rawValue = rawValue
    }

    /// `OBJECT_INHERIT_ACE`
    public static let objectInherit: WindowsACEFlags = .init(rawValue: .init(OBJECT_INHERIT_ACE))
    /// `CONTAINER_INHERIT_ACE`
    public static let containerInherit: WindowsACEFlags = .init(rawValue: .init(CONTAINER_INHERIT_ACE))
    /// `NO_PROPAGATE_INHERIT_ACE`
    public static let noPropagateInherit: WindowsACEFlags = .init(rawValue: .init(NO_PROPAGATE_INHERIT_ACE))
    /// `INHERIT_ONLY_ACE`
    public static let inheritOnly: WindowsACEFlags = .init(rawValue: .init(INHERIT_ONLY_ACE))
    /// `INHERITED_ACE`
    public static let inherited: WindowsACEFlags = .init(rawValue: .init(INHERITED_ACE))
    /// `SUCCESSFUL_ACCESS_ACE_FLAG`
    public static let successfulAccess: WindowsACEFlags = .init(rawValue: .init(SUCCESSFUL_ACCESS_ACE_FLAG))
    /// `FAILED_ACCESS_ACE_FLAG`
    public static let failedAccess: WindowsACEFlags = .init(rawValue: .init(FAILED_ACCESS_ACE_FLAG))

}



/// The type of a Windows ACE
public enum WindowsACEType: BYTE, Sendable, Equatable, Hashable, CustomStringConvertible {

    /// Access allowed ACE (grant access)
    case allow
    /// Access denied ACE (deny access)
    case deny
    /// System audit ACE
    case audit
    /// System alarm ACE
    case alarm

    /// Creates from the native ACE type value
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

    /// The native ACE type value
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



/// The type of a Windows ACL
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



/// The case of a Windows ACL state in a security descriptor, without the associated value.
public enum WindowsACLStateCase: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// The ACL is not specified
    case absent
    /// The ACL is specified but is NULL, granting everyone full access
    case null
    /// The ACL is specified and is present
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



/// Type of memory allocator used on Windows
public enum WindowsMemoryAllocatorType {

    /// Allocate with `GlobalAlloc`
    case globalAlloc 
    /// Allocate with `LocalAlloc`
    case localAlloc
    /// Allocate with Swift's UnsafeMutablePointer.allocate
    case swift
    /// Allocate with Posix `malloc`
    case malloc

    /// Deallocate the given pointer based on the allocator type
    /// - Parameter pointer: The pointer to deallocate
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



/// Wrapper for Windows `ACCESS_MASK`
/// 
/// - Note: This type is intended to be available on all platforms to allow some APIs to be cross-platform, but still
///         it is only meaningful on Windows. On other platforms, the pre-defined static constants all have a value of 0.
public struct WindowsAccessMask: OptionSet, Sendable, Equatable, Hashable, CustomStringConvertible {

    #if !canImport(WinSDK)
    public typealias ACCESS_MASK = UInt32
    #endif

    /// The native ACCESS_MASK value
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
            (.writeOwner, "writeOwner"), (.synchronize, "synchronize"), (.accessSystemSecurity, "accessSystemSecurity"), 
            (.genericRead, "genericRead"), (.genericWrite, "genericWrite"), (.genericExecute, "genericExecute"), 
            (.genericAll, "genericAll"), (.mappedGenericRead, "mappedGenericRead"), 
            (.mappedGenericWrite, "mappedGenericWrite"), (.mappedGenericExecute, "mappedGenericExecute"),
        ] as [(WindowsAccessMask, StaticString)]
        let flagDescriptions = allWithNameAsArray
            .compactMap { (flag, name) in
                self.contains(flag) ? name.description : nil
            }
            .joined(separator: ", ")
        return "0x\(String(rawValue, radix: 16)) [\(flagDescriptions)]"
    }

    /// Creates from the native ACCESS_MASK value
    @inlinable
    public init(rawValue: ACCESS_MASK) {
        self.rawValue = rawValue
    }

    #if canImport(WinSDK)

    /// `FILE_READ_DATA`
    public static let readData: WindowsAccessMask = .init(rawValue: .init(FILE_READ_DATA))
    /// `FILE_LIST_DIRECTORY`
    public static let listDirectory: WindowsAccessMask = .init(rawValue: .init(FILE_LIST_DIRECTORY))
    /// `FILE_WRITE_DATA`
    public static let writeData: WindowsAccessMask = .init(rawValue: .init(FILE_WRITE_DATA))
    /// `FILE_ADD_FILE`
    public static let addFile: WindowsAccessMask = .init(rawValue: .init(FILE_ADD_FILE))
    /// `FILE_APPEND_DATA`
    public static let appendData: WindowsAccessMask = .init(rawValue: .init(FILE_APPEND_DATA))
    /// `FILE_ADD_SUBDIRECTORY`
    public static let addSubdirectory: WindowsAccessMask = .init(rawValue: .init(FILE_ADD_SUBDIRECTORY))
    /// `FILE_READ_EA`
    public static let readExtentedAttrs: WindowsAccessMask = .init(rawValue: .init(FILE_READ_EA))
    /// `FILE_WRITE_EA`
    public static let writeExtendedAttrs: WindowsAccessMask = .init(rawValue: .init(FILE_WRITE_EA))
    /// `FILE_EXECUTE`
    public static let execute: WindowsAccessMask = .init(rawValue: .init(FILE_EXECUTE))
    /// `FILE_TRAVERSE`
    public static let traverse: WindowsAccessMask = .init(rawValue: .init(FILE_TRAVERSE))
    /// `FILE_DELETE_CHILD`
    public static let deleteChild: WindowsAccessMask = .init(rawValue: .init(FILE_DELETE_CHILD))
    /// `FILE_READ_ATTRIBUTES`
    public static let readAttributes: WindowsAccessMask = .init(rawValue: .init(FILE_READ_ATTRIBUTES))
    /// `FILE_WRITE_ATTRIBUTES`
    public static let writeAttributes: WindowsAccessMask = .init(rawValue: .init(FILE_WRITE_ATTRIBUTES))

    /// `DELETE`
    public static let delete: WindowsAccessMask = .init(rawValue: .init(DELETE))
    /// `READ_CONTROL`
    public static let readControl: WindowsAccessMask = .init(rawValue: .init(READ_CONTROL))
    /// `WRITE_DAC`
    public static let writeDAC: WindowsAccessMask = .init(rawValue: .init(WRITE_DAC))
    /// `WRITE_OWNER`
    public static let writeOwner: WindowsAccessMask = .init(rawValue: .init(WRITE_OWNER))
    /// `SYNCHRONIZE`
    public static let synchronize: WindowsAccessMask = .init(rawValue: .init(SYNCHRONIZE))

    /// `ACCESS_SYSTEM_SECURITY`
    public static let accessSystemSecurity: WindowsAccessMask = .init(rawValue: .init(ACCESS_SYSTEM_SECURITY))

    /// `GENERIC_READ`
    public static let genericRead: WindowsAccessMask = .init(rawValue: .init(GENERIC_READ))
    /// `GENERIC_WRITE`
    public static let genericWrite: WindowsAccessMask = .init(rawValue: .init(GENERIC_WRITE))
    /// `GENERIC_EXECUTE`
    public static let genericExecute: WindowsAccessMask = .init(rawValue: .init(GENERIC_EXECUTE))
    /// `GENERIC_ALL`
    public static let genericAll: WindowsAccessMask = .init(rawValue: .init(GENERIC_ALL))

    /// `FILE_GENERIC_READ`
    public static let mappedGenericRead: WindowsAccessMask = .init(rawValue: .init(FILE_GENERIC_READ))
    /// `FILE_GENERIC_WRITE`
    public static let mappedGenericWrite: WindowsAccessMask = .init(rawValue: .init(FILE_GENERIC_WRITE))
    /// `FILE_GENERIC_EXECUTE`
    public static let mappedGenericExecute: WindowsAccessMask = .init(rawValue: .init(FILE_GENERIC_EXECUTE))

    #else

    public static var readData: WindowsAccessMask { .init(rawValue: 0) }
    public static var listDirectory: WindowsAccessMask { .init(rawValue: 0) }
    public static var writeData: WindowsAccessMask { .init(rawValue: 0) }
    public static var addFile: WindowsAccessMask { .init(rawValue: 0) }
    public static var appendData: WindowsAccessMask { .init(rawValue: 0) }
    public static var addSubdirectory: WindowsAccessMask { .init(rawValue: 0) }
    public static var readExtentedAttrs: WindowsAccessMask { .init(rawValue: 0) }
    public static var writeExtendedAttrs: WindowsAccessMask { .init(rawValue: 0) }
    public static var execute: WindowsAccessMask { .init(rawValue: 0) }
    public static var traverse: WindowsAccessMask { .init(rawValue: 0) }
    public static var deleteChild: WindowsAccessMask { .init(rawValue: 0) }
    public static var readAttributes: WindowsAccessMask { .init(rawValue: 0) }
    public static var writeAttributes: WindowsAccessMask { .init(rawValue: 0) }

    public static var delete: WindowsAccessMask { .init(rawValue: 0) }
    public static var readControl: WindowsAccessMask { .init(rawValue: 0) }
    public static var writeDAC: WindowsAccessMask { .init(rawValue: 0) }
    public static var writeOwner: WindowsAccessMask { .init(rawValue: 0) }
    public static var synchronize: WindowsAccessMask { .init(rawValue: 0) }

    public static var accessSystemSecurity: WindowsAccessMask { .init(rawValue: 0) }

    public static var genericRead: WindowsAccessMask { .init(rawValue: 0) }
    public static var genericWrite: WindowsAccessMask { .init(rawValue: 0) }
    public static var genericExecute: WindowsAccessMask { .init(rawValue: 0) }
    public static var genericAll: WindowsAccessMask { .init(rawValue: 0) }

    public static var mappedGenericRead: WindowsAccessMask { .init(rawValue: 0) }
    public static var mappedGenericWrite: WindowsAccessMask { .init(rawValue: 0) }
    public static var mappedGenericExecute: WindowsAccessMask { .init(rawValue: 0) }

    #endif

}
