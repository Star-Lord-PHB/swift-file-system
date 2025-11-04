#if canImport(WinSDK)
import WinSDK
import SystemPackage
import CFileSystem


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


    static func name(ofSid sidStr: String) throws(SystemError) -> String {

        var sidPtr = nil as PSID?

        try execThrowingCFunction {
            sidStr.withCString(encodedAs: UTF16.self) { sidStrPtr in 
                ConvertStringSidToSidW(sidStrPtr, &sidPtr)
            }
        }

        guard let sidPtr else {
            try SystemError.assertError()
        }
        defer { LocalFree(sidPtr) }

        var nameSize = 0 as DWORD
        var domainSize = 0 as DWORD
        var use = SID_NAME_USE(0)

        LookupAccountSidW(nil, sidPtr, nil, &nameSize, nil, &domainSize, nil)
        guard GetLastError() == ERROR_INSUFFICIENT_BUFFER else {
            try SystemError.assertError()
        }

        let nameBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(nameSize))
        let domainBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(domainSize))
        defer {
            nameBuffer.deallocate()
            domainBuffer.deallocate()
        }

        try execThrowingCFunction {
            LookupAccountSidW(nil, sidPtr, nameBuffer, &nameSize, domainBuffer, &domainSize, &use)
        }

        return String(decodingCString: nameBuffer, as: UTF16.self)

    }


    static func windowsPermissionBits(fromPosixPermissionBits bits: CModeT, forDir: Bool = false) -> DWORD {

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
            GetTokenInformation(tokenHandle.unsafeResourcePtr, tokenInfoClass, infoPtr.unsafeRawPtr, size, &size)
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


    static func setEntries(
        _ aclEntries: borrowing [EXPLICIT_ACCESSW], 
        inAcl aclPtr: inout UnsafeOwnedAutoPointer<ACL>
    ) throws(SystemError) {
        var newAclPtr = nil as PACL?
        try execThrowingCFunction {
            aclEntries.withUnsafeBufferPointer { aclEntriesBuffer in 
                SetEntriesInAclW(ULONG(aclEntriesBuffer.count), UnsafeMutablePointer(mutating: aclEntriesBuffer.baseAddress), aclPtr.unsafeRawPtr, &newAclPtr)
            }
        } onError: { (code) throws(SystemError) in
            throw SystemError(code: code)
        }
        guard let newAclPtr else {
            try SystemError.assertError()
        }
        aclPtr.deallocate()
        aclPtr = .init(owningPointer: newAclPtr, allocator: .localAlloc)
    }


    static func makeAcl(from aclEntries: borrowing [EXPLICIT_ACCESSW]) throws(SystemError) -> UnsafeOwnedAutoPointer<ACL> {
        var newAclPtr = nil as PACL?
        try execThrowingCFunction {
            aclEntries.withUnsafeBufferPointer { aclEntriesBuffer in 
                SetEntriesInAclW(ULONG(aclEntriesBuffer.count), UnsafeMutablePointer(mutating: aclEntriesBuffer.baseAddress), nil, &newAclPtr)
            }
        } onError: { (code) throws(SystemError) in
            throw SystemError(code: code)
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
            MakeSelfRelativeSD(absoluteSecurityDescriptorPtr.unsafeRawPtr, nil, &selfRelativeSDSize) == false, 
            GetLastError() == ERROR_INSUFFICIENT_BUFFER 
        else {
            try SystemError.assertError()
        }

        let selfRelativeSDPtr = UnsafeOwnedRawAutoPointer.swiftAllocate(
            byteCount: Int(selfRelativeSDSize), 
            alignment: MemoryLayout<SECURITY_DESCRIPTOR>.alignment
        ).assumingMemoryBound(to: SECURITY_DESCRIPTOR.self)

        try execThrowingCFunction {
            MakeSelfRelativeSD(absoluteSecurityDescriptorPtr.unsafeRawPtr, selfRelativeSDPtr.unsafeRawPtr, &selfRelativeSDSize)
        }

        return selfRelativeSDPtr

    }


    static func securityDescriptor(
        fromPosixPermissions permissions: FilePermissions, 
        forDir: Bool = false
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR> {

        let ownerPermissions = windowsPermissionBits(fromPosixPermissionBits: permissions.rawValue >> 6, forDir: forDir)
        let groupPermissions = windowsPermissionBits(fromPosixPermissionBits: (permissions.rawValue >> 3) & 0b111, forDir: forDir)
        let othersPermissions = windowsPermissionBits(fromPosixPermissionBits: permissions.rawValue & 0b111, forDir: forDir)

        let processToken = try getCurrentProcessTokenHandle()

        let tokenUserPtr = try getTokenInformation(of: TokenUser, from: processToken, as: TOKEN_USER.self)
        let userSidPtr = tokenUserPtr.pointee.User.Sid

        let groupSidPtr = try getTokenInformation(of: TokenPrimaryGroup, from: processToken, as: TOKEN_PRIMARY_GROUP.self)
        let primaryGroupSid = groupSidPtr.pointee.PrimaryGroup

        var worldAuth = getSecurityWorldSidAuthority()
        let everyoneSidPtr = try allocateSid(identifierAuthorityPtr: &worldAuth, subAuthorityCount: 1, DWORD(SECURITY_WORLD_RID), 0, 0, 0, 0, 0, 0, 0)

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
            entry.Trustee.ptstrName = userSidPtr?.assumingMemoryBound(to: WCHAR.self)
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
            entry.Trustee.ptstrName = primaryGroupSid?.assumingMemoryBound(to: WCHAR.self)
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

        let daclPtr = try makeAcl(from: daclEntries)

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
            SetSecurityDescriptorDacl(&securityDescriptor, true, daclPtr.unsafeRawPtr, false)
        }

        // Make the security descriptor self-relative, otherwise its contents will be invalid once this function returns.
        return try UnsafeUnownedPointer.withPointer(to: securityDescriptor) { (securityDescriptorPtr) throws(SystemError) in 
            try makeSelfRelativeSecurityDescriptor(from: securityDescriptorPtr)
        }

    }


    static func effectiveAccessMaskForCurrentProcess(from securityDescriptorPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(SystemError) -> DWORD {
        let processToken = try getCurrentProcessTokenHandle()
        return try effectiveAccessMask(from: securityDescriptorPtr, forSubject: processToken.unownedView())
    }


    static func effectiveAccessMaskForCurrentProcess(
        from securityDescriptorPtr: borrowing UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>
    ) throws(SystemError) -> DWORD {
        return try effectiveAccessMaskForCurrentProcess(from: securityDescriptorPtr.unownedView())
    }


    static func effectiveAccessMask(
        from securityDescriptorPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>, 
        forSubject subjectTokenHandle: UnsafeUnownedResource
    ) throws(SystemError) -> DWORD {

        var authResourceManager = nil as AUTHZ_RESOURCE_MANAGER_HANDLE?
        try execThrowingCFunction {
            AuthzInitializeResourceManager(
                DWORD(AUTHZ_RM_FLAG_NO_AUDIT), 
                nil, nil, nil, nil, 
                &authResourceManager
            )
        }
        guard let authResourceManager else {
            try SystemError.assertError()
        }
        defer { AuthzFreeResourceManager(authResourceManager) }

        var authClientContext = nil as AUTHZ_CLIENT_CONTEXT_HANDLE?
        try execThrowingCFunction {
            AuthzInitializeContextFromToken(0, subjectTokenHandle.unsafeResourcePtr, authResourceManager, nil, LUID(), nil, &authClientContext)
        } 
        guard let authClientContext else {
            try SystemError.assertError()
        }
        defer { AuthzFreeContext(authClientContext) }

        var request = AUTHZ_ACCESS_REQUEST(
            DesiredAccess: DWORD(MAXIMUM_ALLOWED), 
            PrincipalSelfSid: nil, ObjectTypeList: nil, ObjectTypeListLength: 0, OptionalArguments: nil
        )

        var grantedAccessMask = 0 as DWORD
        var error = 0 as DWORD

        try execThrowingCFunction {
            withUnsafeMutablePointer(to: &grantedAccessMask) { grantedAccessMaskPtr in 
                withUnsafeMutablePointer(to: &error) { errorPtr in 
                    var reply = AUTHZ_ACCESS_REPLY(
                        ResultListLength: 1, 
                        GrantedAccessMask: grantedAccessMaskPtr, 
                        SaclEvaluationResults: nil, 
                        Error: errorPtr
                    )
                    return AuthzAccessCheck(0, authClientContext, &request, nil, securityDescriptorPtr.unsafeRawPtr, nil, 0, &reply, nil)
                }
            }
        }

        guard error == SystemError.successCode else {
            throw SystemError(code: error)
        }

        var genericMapping = GENERIC_MAPPING(
            GenericRead: DWORD(GENERIC_READ), 
            GenericWrite: DWORD(GENERIC_WRITE), 
            GenericExecute: DWORD(GENERIC_EXECUTE), 
            GenericAll: DWORD(GENERIC_ALL)
        )

        MapGenericMask(&grantedAccessMask, &genericMapping)

        return grantedAccessMask

    }


    static func destinationPathOfSymbolicLink(at pathPtr: UnsafeUnownedPointer<WCHAR>) throws(SystemError) -> UnsafeOwnedAutoPointer<WCHAR> {

        let handle = CreateFileW(
            pathPtr.unsafeRawPtr, 
            0, 
            DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), 
            nil, 
            DWORD(OPEN_EXISTING), 
            DWORD(FILE_FLAG_BACKUP_SEMANTICS), 
            nil
        )
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try SystemError.assertError()
        }
        defer { CloseHandle(handle) }

        SetLastError(DWORD(ERROR_SUCCESS))
        let pathSize = GetFinalPathNameByHandleW(handle, nil, 0, DWORD(FILE_NAME_NORMALIZED))
        guard pathSize > 0 else {
            try SystemError.assertError()
        }

        let pathBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(pathSize))
        
        SetLastError(DWORD(ERROR_SUCCESS))
        guard GetFinalPathNameByHandleW(handle, pathBuffer, pathSize, DWORD(FILE_NAME_NORMALIZED)) > 0 else {
            try SystemError.assertError()
        }

        return .init(owningPointer: pathBuffer, allocator: .swift)

    }


    static func destinationPathOfSymbolicLink(at path: FilePath) throws(SystemError) -> UnsafeOwnedAutoPointer<WCHAR> {
        let handle = path.withPlatformString { pathPtr in 
            CreateFileW(
                pathPtr, 
                0, 
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), 
                nil, 
                DWORD(OPEN_EXISTING), 
                DWORD(FILE_FLAG_BACKUP_SEMANTICS), 
                nil
            )
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try SystemError.assertError()
        }
        defer { CloseHandle(handle) }

        SetLastError(DWORD(ERROR_SUCCESS))
        let pathSize = GetFinalPathNameByHandleW(handle, nil, 0, DWORD(FILE_NAME_NORMALIZED))
        guard pathSize > 0 else {
            try SystemError.assertError()
        }

        let pathBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(pathSize))
        
        SetLastError(DWORD(ERROR_SUCCESS))
        guard GetFinalPathNameByHandleW(handle, pathBuffer, pathSize, DWORD(FILE_NAME_NORMALIZED)) > 0 else {
            try SystemError.assertError()
        }

        return .init(owningPointer: pathBuffer, allocator: .swift)
    }



    @_lifetime(copy securityDescriptorPtr)
    static func getOwnerSid(from securityDescriptorPtr: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(SystemError) -> (sid: UnsafeUnownedResource, defaulted: Bool) {
        var ownerSidPtr = nil as PSID?
        var ownerDefaulted = false as WindowsBool
        try execThrowingCFunction {
            GetSecurityDescriptorOwner(securityDescriptorPtr.unsafeRawPtr, &ownerSidPtr, &ownerDefaulted)
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
            GetSecurityDescriptorGroup(securityDescriptorPtr.unsafeRawPtr, &groupSidPtr, &groupDefaulted)
        }
        guard let groupSidPtr else {
            try SystemError.assertError()
        }
        return (sid: .init(unownedResource: groupSidPtr), defaulted: groupDefaulted.boolValue)
    }


    static func getFileSecurity(
        at path: FilePath, 
        requesting information: SECURITY_INFORMATION
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR> {

        var descriptorSize = 0 as DWORD

        let getFileSecurityResult = path.string.withCString(encodedAs: UTF16.self) { pathPtr in 
            GetFileSecurityW(pathPtr, information, nil, 0, &descriptorSize)
        }
        guard getFileSecurityResult == false && GetLastError() == ERROR_INSUFFICIENT_BUFFER else {
            try SystemError.assertError()
        }

        let securityDescriptorPtr = UnsafeMutableRawPointer.allocate(byteCount: Int(descriptorSize), alignment: MemoryLayout<SECURITY_DESCRIPTOR>.alignment)

        try execThrowingCFunction {
            path.string.withCString(encodedAs: UTF16.self) { pathPtr in 
                GetFileSecurityW(pathPtr, information, securityDescriptorPtr, descriptorSize, &descriptorSize)
            }
        }

        return .init(owningPointer: securityDescriptorPtr.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self), allocator: .swift)

    }

}

#endif