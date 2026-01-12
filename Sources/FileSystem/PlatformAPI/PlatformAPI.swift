import PlatformCLib


public final class PlatformAPI: PlatformAPIProtocol {

    public init() { }

}



extension PlatformAPI {

    public func accountName(for identity: PlatformIdentity) throws(FileError) -> String? {

        #if canImport(WinSDK)

        var nameSize = 0 as DWORD
        var domainSize = 0 as DWORD
        var use = SID_NAME_USE(0)

        LookupAccountSidW(nil, identity.rawId.psid.unsafeResourcePtr, nil, &nameSize, nil, &domainSize, nil)
        let error = GetLastError()
        guard error == ERROR_INSUFFICIENT_BUFFER else {
            if error == ERROR_NONE_MAPPED { return nil }
            throw FileError(code: .platform(.init(rawValue: error)), operationDescription: .queryingAccountName(for: identity)) 
                ?? .unknown(operationDescription: .queryingAccountName(for: identity))
        }

        let nameBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(nameSize))
        let domainBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(domainSize))
        defer {
            nameBuffer.deallocate()
            domainBuffer.deallocate()
        }

        do {
            try execThrowingCFunction(operationDescription: .queryingAccountName(for: identity)) {
                LookupAccountSidW(nil, identity.rawId.psid.unsafeResourcePtr, nameBuffer, &nameSize, domainBuffer, &domainSize, &use)
            }
        } catch let error where error.code.rawValue == DWORD(ERROR_NONE_MAPPED) {
            return nil
        }

        return String(decodingCString: nameBuffer, as: UTF16.self)

        #else 

        switch identity.kind {

            case .user: do {

                var size = sysconf(Int32(_SC_GETPW_R_SIZE_MAX))
                if size <= 0 { size = 1024 }

                var pwd = passwd()
                var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
                defer { buffer.deallocate() }
                var result = nil as UnsafeMutablePointer<passwd>?

                while true {

                    let error = getpwuid_r(identity.rawId, &pwd, buffer, size, &result)

                    if error == 0 { break }
                    if error == ERANGE {
                        size *= 2
                        buffer.deallocate()
                        buffer = .allocate(capacity: size)
                        continue
                    }

                    throw FileError(code: .platform(.init(rawValue: error)), operationDescription: .queryingAccountName(for: identity))!

                }

                if result == nil { return nil }

                return String(cString: pwd.pw_name, encoding: .utf8)

            }

            case .group: do {

                var size = sysconf(Int32(_SC_GETGR_R_SIZE_MAX))
                if size <= 0 { size = 1024 }

                var grp = group()
                var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
                defer { buffer.deallocate() }
                var result = nil as UnsafeMutablePointer<group>?

                while true {

                    let error = getgrgid_r(identity.rawId, &grp, buffer, size, &result)

                    if error == 0 { break }
                    if error == ERANGE {
                        size *= 2
                        buffer.deallocate()
                        buffer = .allocate(capacity: size)
                        continue
                    }

                    throw FileError(code: .platform(.init(rawValue: error)), operationDescription: .queryingAccountName(for: identity))!

                }

                if result == nil { return nil }

                return String(cString: grp.gr_name, encoding: .utf8)

            }

        }

        #endif 

    }


    #if canImport(WinSDK)
    public func identity(forAccountName name: String) throws(FileError) -> PlatformIdentity? {
        
        var sidSize = 0 as DWORD
        var domainSize = 0 as DWORD
        var use = SID_NAME_USE(0)

        name.withCString(encodedAs: UTF16.self) { namePtr in 
            _ = LookupAccountNameW(nil, namePtr, nil, &sidSize, nil, &domainSize, &use)
        }
        let error = GetLastError()
        guard error == ERROR_INSUFFICIENT_BUFFER else {
            if error == ERROR_NONE_MAPPED { return nil }
            throw FileError(code: .platform(.init(rawValue: error)), operationDescription: .queryingIdentity(forAccountName: name)) 
                ?? .unknown(operationDescription: .queryingIdentity(forAccountName: name))
        }

        let sidBuffer = UnsafeMutableRawPointer.allocate(byteCount: Int(sidSize), alignment: MemoryLayout<UInt8>.alignment)
        let domainBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(domainSize))
        defer {
            domainBuffer.deallocate()
        }

        do {
            try execThrowingCFunction(operationDescription: .queryingIdentity(forAccountName: name)) {
                name.withCString(encodedAs: UTF16.self) { namePtr in 
                    LookupAccountNameW(nil, namePtr, sidBuffer, &sidSize, domainBuffer, &domainSize, &use)
                }
            }
        } catch let error where error.code.rawValue == DWORD(ERROR_NONE_MAPPED) {
            sidBuffer.deallocate()
            return nil
        } catch {
            sidBuffer.deallocate()
            throw error
        }

        return .init(rawId: .init(unsafeOwningPSid: sidBuffer, freeingFunc: { $0.deallocate() }))

    }
    #else 
    public func identity(forAccountName name: String, kind: PlatformIdentity.Kind) throws(FileError) -> PlatformIdentity? {

        switch kind {

            case .user: do {

                var pwd = passwd()
                var size = sysconf(Int32(_SC_GETPW_R_SIZE_MAX))
                if size <= 0 { size = 1024 }

                var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
                defer { buffer.deallocate() }
                var result = nil as UnsafeMutablePointer<passwd>?

                while true {

                    let error = getpwnam_r(name, &pwd, buffer, size, &result)

                    if error == 0 { break }
                    if error == ERANGE {
                        size *= 2
                        buffer.deallocate()
                        buffer = .allocate(capacity: size)
                        continue
                    }

                    throw FileError(code: .platform(.init(rawValue: error)), operationDescription: .queryingIdentity(forAccountName: name))!

                }

                guard result != nil else { return nil }

                return PlatformIdentity(rawId: pwd.pw_uid, kind: .user)

            }

            case .group: do {

                var grp = group()
                var size = sysconf(Int32(_SC_GETGR_R_SIZE_MAX))
                if size <= 0 { size = 1024 }

                var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: size)
                defer { buffer.deallocate() }
                var result = nil as UnsafeMutablePointer<group>?

                while true {

                    let error = getgrnam_r(name, &grp, buffer, size, &result)

                    if error == 0 { break }
                    if error == ERANGE {
                        size *= 2
                        buffer.deallocate()
                        buffer = .allocate(capacity: size)
                        continue
                    }

                    throw FileError(code: .platform(.init(rawValue: error)), operationDescription: .queryingIdentity(forAccountName: name))!

                }

                guard result != nil else { return nil }

                return PlatformIdentity(rawId: grp.gr_gid, kind: .group)

            }

        }

    }
    #endif 


    public func currentIdentity() throws(FileError) -> PlatformIdentity {

        #if canImport(WinSDK)

        let tokenUserPtr = try catchSystemError(operationDescription: .queryingCurrentIdentity()) { () throws(SystemError) in
            let currentProcessToken = try WindowsAPI.getCurrentProcessTokenHandle()
            return try WindowsAPI.getTokenInformation(of: TokenUser, from: currentProcessToken, as: TOKEN_USER.self)
        }

        // Ths SID in the tokenUserPtr is owned by that value, so we need to first copy it out 

        let sidSize = WindowsAPI.getSidLength(sidPtr: .init(unownedResource: tokenUserPtr.pointee.User.Sid))
        let copiedSidBuffer = UnsafeMutableRawPointer.allocate(byteCount: Int(sidSize), alignment: MemoryLayout<SID>.alignment)
        copiedSidBuffer.copyMemory(from: tokenUserPtr.pointee.User.Sid, byteCount: Int(sidSize))

        return .init(rawId: .init(unsafeOwningPSid: copiedSidBuffer, freeingFunc: { $0.deallocate() }))

        #else 

        let uid = getuid()
        return PlatformIdentity(rawId: uid, kind: .user)

        #endif
    
    }


    #if canImport(WinSDK)
    public func effectiveAccessMask(
        for identity: PlatformIdentity, 
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(FileError) -> WindowsAccessMask {
        
        var authResourceManager = nil as AUTHZ_RESOURCE_MANAGER_HANDLE?
        try execThrowingCFunction(operationDescription: .queryingEffectiveAccessMask(for: identity)) {
            AuthzInitializeResourceManager(
                DWORD(AUTHZ_RM_FLAG_NO_AUDIT), 
                nil, nil, nil, nil, 
                &authResourceManager
            )
        }
        guard let authResourceManager else {
            try FileError.assertError(fallbackToUnknownError: true, operationDescription: .queryingEffectiveAccessMask(for: identity))
        }
        defer { AuthzFreeResourceManager(authResourceManager) }

        var authClientContext = nil as AUTHZ_CLIENT_CONTEXT_HANDLE?
        try execThrowingCFunction(operationDescription: .queryingEffectiveAccessMask(for: identity)) {
            AuthzInitializeContextFromSid(0, identity.rawId.psid.unsafeResourcePtr, authResourceManager, nil, LUID(), nil, &authClientContext)
        } 
        guard let authClientContext else {
            try FileError.assertError(fallbackToUnknownError: true, operationDescription: .queryingEffectiveAccessMask(for: identity))
        }
        defer { AuthzFreeContext(authClientContext) }

        var request = AUTHZ_ACCESS_REQUEST(
            DesiredAccess: DWORD(MAXIMUM_ALLOWED), 
            PrincipalSelfSid: nil, ObjectTypeList: nil, ObjectTypeListLength: 0, OptionalArguments: nil
        )

        var grantedAccessMask = 0 as DWORD
        var error = 0 as DWORD

        try execThrowingCFunction(operationDescription: .queryingEffectiveAccessMask(for: identity)) {
            withUnsafeMutablePointer(to: &grantedAccessMask) { grantedAccessMaskPtr in 
                withUnsafeMutablePointer(to: &error) { errorPtr in 
                    var reply = AUTHZ_ACCESS_REPLY(
                        ResultListLength: 1, 
                        GrantedAccessMask: grantedAccessMaskPtr, 
                        SaclEvaluationResults: nil, 
                        Error: errorPtr
                    )
                    return AuthzAccessCheck(0, authClientContext, &request, nil, securityDescriptor.psd.unsafelyCastedMutableRawPtr, nil, 0, &reply, nil)
                }
            }
        }

        guard error == SystemError.successCode else {
            throw FileError(code: .platform(.init(rawValue: error)), operationDescription: .queryingEffectiveAccessMask(for: identity))!
        }

        var genericMapping = GENERIC_MAPPING(
            GenericRead: DWORD(GENERIC_READ), 
            GenericWrite: DWORD(GENERIC_WRITE), 
            GenericExecute: DWORD(GENERIC_EXECUTE), 
            GenericAll: DWORD(GENERIC_ALL)
        )

        MapGenericMask(&grantedAccessMask, &genericMapping)

        return .init(rawValue: grantedAccessMask)

    }


    public func effectiveAccessMaskForCurrentProcess(
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(FileError) -> WindowsAccessMask {
        try effectiveAccessMask(for: currentIdentity(), whenAccessing: securityDescriptor)
    }
    #endif 

}