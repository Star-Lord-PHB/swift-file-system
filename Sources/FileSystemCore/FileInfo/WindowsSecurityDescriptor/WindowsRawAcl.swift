#if canImport(WinSDK)

import PlatformCLib
import struct SystemPackage.FilePermissions
import struct SystemPackage.CModeT


public struct WindowsRawAcl: ~Copyable, WindowRawAclProtocol {

    private(set) var pacl: UnsafeOwnedAutoPointer<ACL>

    public var view: View {
        @_lifetime(borrow self)
        get {
            .init(pacl: pacl.unownedView())
        }
    }

    package init(pacl: consuming UnsafeOwnedAutoPointer<ACL>) {
        self.pacl = pacl
        precondition(IsValidAcl(self.pacl.unsafelyCastedMutableRawPtr), "Invalid ACL pointer")
    }

    public init(entries: WindowsExplicitAccessArray = []) {
        let pacl = UnsafeMutablePointer<ACL>.allocate(capacity: 1)
        InitializeAcl(pacl, DWORD(MemoryLayout<ACL>.size), DWORD(ACL_REVISION))
        self.init(pacl: .init(owningPointer: pacl, allocator: .swift))
        if !entries.isEmpty {
            self.addEntries(entries)
        }
    }

    public init(unsafeOwningAclPtr: PACL, allocator: WindowsMemoryAllocatorType) {
        self.init(pacl: .init(owningPointer: unsafeOwningAclPtr, allocator: allocator.mappedInternalAllocatorType))
    }

    public mutating func addEntries(_ entries: WindowsExplicitAccessArray) {
        entries.withUnsafeRawExplicitAccessBuffer { ptr in
            let newPacl = try! Self.addEntries(.init(unownedBuffer: ptr), toAcl: self.pacl.unownedView())
            self = .init(pacl: newPacl)
        }
    }

    public func withUnsafePACL<R, E>(_ operation: (PACL) throws(E) -> R) throws(E) -> R where E : Error, R : ~Copyable {
        return try operation(pacl.unsafelyCastedMutableRawPtr)
    }

    public static var emptyAcl: WindowsRawAcl { .init() }

    public struct View: ~Escapable, WindowRawAclProtocol {

        let pacl: UnsafeUnownedPointer<ACL>

        @_lifetime(copy pacl)
        init(pacl: UnsafeUnownedPointer<ACL>) {
            precondition(IsValidAcl(pacl.unsafelyCastedMutableRawPtr), "Invalid ACL pointer")
            self.pacl = pacl
        }

        public func withUnsafePACL<R, E>(_ operation: (PACL) throws(E) -> R) throws(E) -> R where E : Error, R : ~Copyable {
            return try operation(pacl.unsafelyCastedMutableRawPtr)
        }

        /// Copies the viewed ACL into an owning ``WindowsRawAcl``.
        public func detach() -> WindowsRawAcl {
            do {
                return .init(pacl: try WindowsRawAcl.addEntries(nil, toAcl: pacl))
            } catch {
                fatalError("Failed to copy ACL: \(error)")
            }
        }

    }

}



extension WindowsRawAcl {

    package static func makeForCurrentUser(fromPosixPermissions permissions: FilePermissions, forDir: Bool = false) throws(LowLevelError) -> Self {

        let processToken = try WindowsProcessToken.current()

        let tokenUserPtr = try processToken.getUser()
        let userSidPtr = tokenUserPtr.pointee.User.Sid

        let groupSidPtr = try processToken.getPrimaryGroups()
        let primaryGroupSid = groupSidPtr.pointee.PrimaryGroup

        return try .init(
            fromPosixPermissions: permissions,
            ownerSidPtr: userSidPtr == nil ? nil : .init(unownedResource: userSidPtr!),
            groupSidPtr: primaryGroupSid == nil ? nil : .init(unownedResource: primaryGroupSid!),
            forDir: forDir
        )

    }


    package init(
        fromPosixPermissions permissions: FilePermissions,
        ownerSidPtr: UnsafeUnownedResource?,
        groupSidPtr: UnsafeUnownedResource?,
        forDir: Bool = false
    ) throws(LowLevelError) {

        let ownerPermissions = Self.windowsAcePermissionBits(fromPosixPermissionBits: permissions.rawValue >> 6, forDir: forDir)
        let groupPermissions = Self.windowsAcePermissionBits(fromPosixPermissionBits: (permissions.rawValue >> 3) & 0b111, forDir: forDir)
        let othersPermissions = Self.windowsAcePermissionBits(fromPosixPermissionBits: permissions.rawValue & 0b111, forDir: forDir)

        let everyoneSidPtr = WindowsSid.everyone.psid

        var daclEntries = [] as [EXPLICIT_ACCESSW]

        do {
            // Will always be added to the DACL even if no permissions are granted.
            var entry = EXPLICIT_ACCESSW()
            entry.grfAccessMode = GRANT_ACCESS
            entry.grfAccessPermissions = ownerPermissions
            if forDir {
                entry.grfInheritance = DWORD(CONTAINER_INHERIT_ACE | OBJECT_INHERIT_ACE)
            }
            entry.Trustee.TrusteeForm = TRUSTEE_IS_SID
            entry.Trustee.TrusteeType = TRUSTEE_IS_USER
            entry.Trustee.ptstrName = ownerSidPtr?.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            daclEntries.append(entry)
        }

        if groupPermissions != 0 {
            var entry = EXPLICIT_ACCESSW()
            entry.grfAccessMode = GRANT_ACCESS
            entry.grfAccessPermissions = groupPermissions
            if forDir {
                entry.grfInheritance = DWORD(CONTAINER_INHERIT_ACE | OBJECT_INHERIT_ACE)
            }
            entry.Trustee.TrusteeForm = TRUSTEE_IS_SID
            entry.Trustee.TrusteeType = TRUSTEE_IS_GROUP
            entry.Trustee.ptstrName = groupSidPtr?.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            daclEntries.append(entry)
        }

        if othersPermissions != 0 {
            var entry = EXPLICIT_ACCESSW()
            entry.grfAccessMode = GRANT_ACCESS
            entry.grfAccessPermissions = othersPermissions
            if forDir {
                entry.grfInheritance = DWORD(CONTAINER_INHERIT_ACE | OBJECT_INHERIT_ACE)
            }
            entry.Trustee.TrusteeForm = TRUSTEE_IS_SID
            entry.Trustee.TrusteeType = TRUSTEE_IS_WELL_KNOWN_GROUP
            entry.Trustee.ptstrName = everyoneSidPtr.unsafeResourcePtr.assumingMemoryBound(to: WCHAR.self)
            daclEntries.append(entry)
        }

        self.pacl = try daclEntries.span.withUnsafeBufferPointer { (buffer) throws(LowLevelError) in
            try WindowsRawAcl.addEntries(.init(unownedBuffer: buffer), toAcl: nil)
        }

    }


    private static func windowsAcePermissionBits(fromPosixPermissionBits bits: CModeT, forDir: Bool = false) -> DWORD {
        var permissions = DWORD(0)
        if bits & 0b100 != 0 {
            permissions |= DWORD(FILE_READ_ATTRIBUTES | FILE_READ_EA | FILE_READ_DATA | STANDARD_RIGHTS_READ | SYNCHRONIZE)
            if forDir {
                permissions |= DWORD(FILE_LIST_DIRECTORY)
            }
        }
        if bits & 0b010 != 0 {
            permissions |= DWORD(FILE_WRITE_ATTRIBUTES | FILE_WRITE_EA | FILE_WRITE_DATA | FILE_APPEND_DATA | STANDARD_RIGHTS_WRITE | SYNCHRONIZE | DELETE)
            if forDir {
                permissions |= DWORD(FILE_ADD_FILE | FILE_ADD_SUBDIRECTORY | FILE_DELETE_CHILD)
            }
        }
        if bits & 0b001 != 0 {
            permissions |= DWORD(FILE_EXECUTE | STANDARD_RIGHTS_EXECUTE | SYNCHRONIZE)
            if forDir {
                permissions |= DWORD(FILE_TRAVERSE)
            }
        }
        return permissions
    }


    fileprivate static func addEntries(
        _ entries: UnsafeUnownedBufferPointer<EXPLICIT_ACCESSW>?,
        toAcl acl: UnsafeUnownedPointer<ACL>?
    ) throws(LowLevelError) -> UnsafeOwnedAutoPointer<ACL> {
        var newAclPtr = nil as PACL?
        try execThrowingCFunction {
            SetEntriesInAclW(
                DWORD(entries?.count ?? 0),
                entries?.baseAddress?.unsafeMutableCast().unsafeRawPtr,
                acl?.unsafelyCastedMutableRawPtr,
                &newAclPtr
            )
        } onError: { (code) throws(LowLevelError) in
            throw LowLevelError(rawSystemCode: code)!
        }
        guard let newAclPtr else {
            try LowLevelError.assertError()
        }
        return .init(owningPointer: newAclPtr, allocator: .localAlloc)
    }

}

#endif
