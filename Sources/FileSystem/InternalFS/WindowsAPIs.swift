#if canImport(WinSDK)
import WinSDK
import SystemPackage
import CFileSystem


/// A collections of wrappers around Win32 APIs that are not directly related to file system operations.
enum WindowsAPI {

    static func pSidToString(sidPtr: UnsafeUnownedResource) throws(SystemError) -> String {

        var sidStrPtr = nil as LPWSTR?
        try execThrowingCFunction {
            ConvertSidToStringSidW(sidPtr.unsafeResourcePtr, &sidStrPtr)
        }
        guard let sidStrPtr else {
            try SystemError.assertError()
        }
        defer { LocalFree(sidStrPtr) }

        return String(decodingCString: sidStrPtr, as: UTF16.self)

    }


    static func pSidToString(sidPtr: borrowing UnsafeOwnedAutoResource) throws(SystemError) -> String {
        return try pSidToString(sidPtr: sidPtr.unownedView())
    }


    static func stringToPsid(sidStr: String) throws(SystemError) -> UnsafeOwnedAutoResource {

        var sidPtr = nil as PSID?
        try execThrowingCFunction {
            sidStr.withCString(encodedAs: UTF16.self) { sidStrPtr in 
                ConvertStringSidToSidW(sidStrPtr, &sidPtr)
            }
        }

        guard let sidPtr else {
            try SystemError.assertError()
        }

        return .init(owningResource: sidPtr, freeingFunc: { LocalFree($0) })

    }


    static func windowsAcePermissionBits(fromPosixPermissionBits bits: CModeT, forDir: Bool = false) -> DWORD {

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


    static func getCurrentProcessTokenHandle() throws(SystemError) -> UnsafeOwnedAutoResource {
        var processToken = nil as HANDLE?
        try execThrowingCFunction {
            OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &processToken)
        }
        guard let processToken else {
            try SystemError.assertError()
        }
        return .init(owningResource: processToken, freeingFunc: { CloseHandle($0) })
    }


    static func getTokenInformation<T>(
        of tokenInfoClass: TOKEN_INFORMATION_CLASS, 
        from tokenHandle: UnsafeUnownedResource, 
        as type: T.Type
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<T> {
        var size = 0 as DWORD
        guard 
            GetTokenInformation(tokenHandle.unsafeResourcePtr, tokenInfoClass, nil, 0, &size) == false, 
            GetLastError() == ERROR_INSUFFICIENT_BUFFER 
        else {
            try SystemError.assertError()
        }
        let infoPtr = UnsafeOwnedRawAutoPointer
            .swiftAllocate(byteCount: Int(size), alignment: MemoryLayout<T>.alignment)
            .assumingMemoryBound(to: T.self)
        try execThrowingCFunction {
            GetTokenInformation(tokenHandle.unsafeResourcePtr, tokenInfoClass, infoPtr.unsafelyCastedMutableRawPtr, size, &size)
        }
        return infoPtr
    }


    static func getTokenInformation<T>(
        of tokenInfoClass: TOKEN_INFORMATION_CLASS, 
        from tokenHandle: borrowing UnsafeOwnedAutoResource, 
        as type: T.Type
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<T> {
        return try getTokenInformation(of: tokenInfoClass, from: tokenHandle.unownedView(), as: type)
    }


    static func allocateSid(
        identifierAuthorityPtr: PSID_IDENTIFIER_AUTHORITY, 
        subAuthorityCount: BYTE, 
        _ subAuthority0: DWORD, 
        _ subAuthority1: DWORD, 
        _ subAuthority2: DWORD, 
        _ subAuthority3: DWORD, 
        _ subAuthority4: DWORD, 
        _ subAuthority5: DWORD, 
        _ subAuthority6: DWORD, 
        _ subAuthority7: DWORD
    ) throws(SystemError) -> UnsafeOwnedAutoResource {

        var sidPtr = nil as PSID?

        try execThrowingCFunction {
            AllocateAndInitializeSid(
                identifierAuthorityPtr, 
                subAuthorityCount, 
                subAuthority0, 
                subAuthority1, 
                subAuthority2, 
                subAuthority3, 
                subAuthority4, 
                subAuthority5, 
                subAuthority6, 
                subAuthority7, 
                &sidPtr
            )
        }
        guard let sidPtr else {
            try SystemError.assertError()
        }

        return .init(owningResource: sidPtr, freeingFunc: { FreeSid($0) })

    }


    static func makeAcl(from aclEntries: UnsafeUnownedBufferPointer<EXPLICIT_ACCESSW>) throws(SystemError) -> UnsafeOwnedAutoPointer<ACL> {
        return try setEntriesInAcl(for: nil, entires: aclEntries)
    }


    static func setEntriesInAcl(
        for acl: consuming UnsafeOwnedAutoPointer<ACL>?, 
        entires aclEntries: UnsafeUnownedBufferPointer<EXPLICIT_ACCESSW>,
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<ACL> {

        var newAclPtr = nil as PACL?
        try execThrowingCFunction {
            SetEntriesInAclW(ULONG(aclEntries.count), aclEntries.baseAddress?.unsafelyCastedMutableRawPtr, acl?.unsafelyCastedMutableRawPtr, &newAclPtr)
        } onError: { (code) throws(SystemError) in
            throw SystemError(code: code)!
        }
        guard let newAclPtr else {
            try SystemError.assertError()
        }
        return .init(owningPointer: newAclPtr, allocator: .localAlloc)

    }


    static func makeSelfRelativeSecurityDescriptor(
        from absoluteSecurityDescriptorPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR> {

        var selfRelativeSDSize = 0 as DWORD
        guard 
            MakeSelfRelativeSD(absoluteSecurityDescriptorPtr.unsafelyCastedMutableRawPtr, nil, &selfRelativeSDSize) == false, 
            GetLastError() == ERROR_INSUFFICIENT_BUFFER 
        else {
            try SystemError.assertError()
        }

        let selfRelativeSDPtr = UnsafeOwnedRawAutoPointer.swiftAllocate(
            byteCount: Int(selfRelativeSDSize), 
            alignment: MemoryLayout<SECURITY_DESCRIPTOR>.alignment
        ).assumingMemoryBound(to: SECURITY_DESCRIPTOR.self)

        try execThrowingCFunction {
            MakeSelfRelativeSD(absoluteSecurityDescriptorPtr.unsafelyCastedMutableRawPtr, selfRelativeSDPtr.unsafelyCastedMutableRawPtr, &selfRelativeSDSize)
        }

        return selfRelativeSDPtr

    }


    static func dacl(
        fromPosixPermissions permissions: FilePermissions, 
        ownerSidPtr: UnsafeUnownedResource?,
        groupSidPtr: UnsafeUnownedResource?,
        forDir: Bool = false
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<ACL> {

        let ownerPermissions = windowsAcePermissionBits(fromPosixPermissionBits: permissions.rawValue >> 6, forDir: forDir)
        let groupPermissions = windowsAcePermissionBits(fromPosixPermissionBits: (permissions.rawValue >> 3) & 0b111, forDir: forDir)
        let othersPermissions = windowsAcePermissionBits(fromPosixPermissionBits: permissions.rawValue & 0b111, forDir: forDir)

        let everyoneSidPtr = try createWellKnownSid(type: WinWorldSid)

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

        return try daclEntries.span.withUnsafeBufferPointer { (buffer) throws(SystemError) in 
            try makeAcl(from: .init(unownedBuffer: buffer))
        }

    }


    static func dacl(
        fromPosixPermissions permissions: FilePermissions, 
        forDir: Bool = false
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<ACL> {

        let processToken = try getCurrentProcessTokenHandle()

        let tokenUserPtr = try getTokenInformation(of: TokenUser, from: processToken, as: TOKEN_USER.self)
        let userSidPtr = tokenUserPtr.pointee.User.Sid

        let groupSidPtr = try getTokenInformation(of: TokenPrimaryGroup, from: processToken, as: TOKEN_PRIMARY_GROUP.self)
        let primaryGroupSid = groupSidPtr.pointee.PrimaryGroup

        return try dacl(
            fromPosixPermissions: permissions, 
            ownerSidPtr: userSidPtr != nil ? .init(unownedResource: userSidPtr!) : nil, 
            groupSidPtr: primaryGroupSid != nil ? .init(unownedResource: primaryGroupSid!) : nil, 
            forDir: forDir
        )

    }


    static func securityDescriptor(
        fromPosixPermissions permissions: FilePermissions, 
        forDir: Bool = false
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR> {

        let processToken = try getCurrentProcessTokenHandle()

        let tokenUserPtr = try getTokenInformation(of: TokenUser, from: processToken, as: TOKEN_USER.self)
        let userSidPtr = tokenUserPtr.pointee.User.Sid

        let groupSidPtr = try getTokenInformation(of: TokenPrimaryGroup, from: processToken, as: TOKEN_PRIMARY_GROUP.self)
        let primaryGroupSid = groupSidPtr.pointee.PrimaryGroup

        let daclPtr = try dacl(
            fromPosixPermissions: permissions, 
            ownerSidPtr: userSidPtr != nil ? .init(unownedResource: userSidPtr!) : nil,
            groupSidPtr: primaryGroupSid != nil ? .init(unownedResource: primaryGroupSid!) : nil,
            forDir: forDir
        )

        var securityDescriptor = SECURITY_DESCRIPTOR()
        try execThrowingCFunction {
            InitializeSecurityDescriptor(&securityDescriptor, DWORD(SECURITY_DESCRIPTOR_REVISION))
        }
        try execThrowingCFunction {
            SetSecurityDescriptorOwner(&securityDescriptor, userSidPtr, false)
        }
        try execThrowingCFunction {
            SetSecurityDescriptorGroup(&securityDescriptor, primaryGroupSid, false)
        }
        try execThrowingCFunction {
            SetSecurityDescriptorDacl(&securityDescriptor, true, daclPtr.unsafelyCastedMutableRawPtr, false)
        }

        // Make the security descriptor self-relative, otherwise its contents will be invalid once this function returns.
        return try UnsafeUnownedPointer.withPointer(to: securityDescriptor) { (securityDescriptorPtr) throws(SystemError) in 
            try makeSelfRelativeSecurityDescriptor(from: securityDescriptorPtr)
        }

    }


    static func getControl(from securityDescriptorPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(SystemError) -> (SECURITY_DESCRIPTOR_CONTROL, DWORD) {
        var revision = 0 as DWORD
        var control = 0 as SECURITY_DESCRIPTOR_CONTROL
        GetSecurityDescriptorControl(securityDescriptorPtr.unsafelyCastedMutableRawPtr, &control, &revision)
        return (control, revision)
    }


    @_lifetime(copy securityDescriptorPtr)
    static func getOwnerSid(from securityDescriptorPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(SystemError) -> (sid: UnsafeUnownedResource, defaulted: Bool) {
        var ownerSidPtr = nil as PSID?
        var ownerDefaulted = false as WindowsBool
        try execThrowingCFunction {
            GetSecurityDescriptorOwner(securityDescriptorPtr.unsafelyCastedMutableRawPtr, &ownerSidPtr, &ownerDefaulted)
        }
        guard let ownerSidPtr else {
            try SystemError.assertError()
        }
        return (sid: .init(unownedResource: ownerSidPtr), defaulted: ownerDefaulted.boolValue)
    }


    @_lifetime(copy securityDescriptorPtr)
    static func getGroupSid(from securityDescriptorPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(SystemError) -> (sid: UnsafeUnownedResource, defaulted: Bool) {
        var groupSidPtr = nil as PSID?
        var groupDefaulted = false as WindowsBool
        try execThrowingCFunction {
            GetSecurityDescriptorGroup(securityDescriptorPtr.unsafelyCastedMutableRawPtr, &groupSidPtr, &groupDefaulted)
        }
        guard let groupSidPtr else {
            try SystemError.assertError()
        }
        return (sid: .init(unownedResource: groupSidPtr), defaulted: groupDefaulted.boolValue)
    }


    static func equalSid(sid1: UnsafeUnownedResource, sid2: UnsafeUnownedResource) -> Bool {
        return EqualSid(sid1.unsafeResourcePtr, sid2.unsafeResourcePtr)
    }

    
    static func getSidLength(sidPtr: UnsafeUnownedResource) -> DWORD {
        return GetLengthSid(sidPtr.unsafeResourcePtr)
    }


    static func createWellKnownSid(type: WELL_KNOWN_SID_TYPE, domainSid: UnsafeUnownedResource? = nil) throws(SystemError) -> UnsafeOwnedAutoResource {

        // 256 bytes should be enough for any well-known SID
        var buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 256, alignment: MemoryLayout<UInt8>.alignment)
        var size = DWORD(buffer.count)
        do {
            try execThrowingCFunction {
                CreateWellKnownSid(type, domainSid?.unsafeResourcePtr, buffer.baseAddress!, &size)
            }
            return .init(owningResource: buffer.baseAddress!, freeingFunc: { $0.deallocate() })
        } catch let error where error.code == .platform(.insufficientBuffer) {
            // ignore this error and retry
        }

        buffer.deallocate()
        buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<UInt8>.alignment)
        try execThrowingCFunction {
            CreateWellKnownSid(type, domainSid?.unsafeResourcePtr, buffer.baseAddress!, &size)
        }
        return .init(owningResource: buffer.baseAddress!, freeingFunc: { $0.deallocate() })

    }

}

#endif