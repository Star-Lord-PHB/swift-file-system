import PlatformCLib


package enum InternalPlatformAPI {

    package static func accountName(for identity: PlatformIdentity) throws(SystemError) -> String? {

        #if canImport(WinSDK)

        var nameSize = 0 as DWORD
        var domainSize = 0 as DWORD
        var use = SID_NAME_USE(0)

        LookupAccountSidW(nil, identity.rawId.psid.unsafeResourcePtr, nil, &nameSize, nil, &domainSize, nil)
        let error = GetLastError()
        guard error == ERROR_INSUFFICIENT_BUFFER else {
            if error == ERROR_NONE_MAPPED { return nil }
            throw SystemError(code: error) ?? .init(code: .extended(.unknown))!
        }

        let nameBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(nameSize))
        let domainBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(domainSize))
        defer {
            nameBuffer.deallocate()
            domainBuffer.deallocate()
        }

        do {
            try execThrowingCFunction {
                LookupAccountSidW(nil, identity.rawId.psid.unsafeResourcePtr, nameBuffer, &nameSize, domainBuffer, &domainSize, &use)
            }
        } catch let error where error.code.rawValue == DWORD(ERROR_NONE_MAPPED) {
            return nil
        }

        return String(decodingCString: nameBuffer, as: UTF16.self)

        #else 

        switch identity.platformKind {

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

                    throw SystemError(code: error)!

                }

                if result == nil { return nil }
                
                return pwd.pw_name.withMemoryRebound(to: UTF8.CodeUnit.self, capacity: 1) { pointer in
                    String(decodingCString: pointer, as: UTF8.self)
                }

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

                    throw SystemError(code: error)!

                }

                if result == nil { return nil }

                return grp.gr_name.withMemoryRebound(to: UTF8.CodeUnit.self, capacity: 1) { pointer in
                    String(decodingCString: pointer, as: UTF8.self)
                }

            }

        }

        #endif 

    }
    
    
    package static func identity(
        forAccountName name: String,
        resolvePreference: PlatformIdentity.AccountNameResolvePreference = .preferUser
    ) throws(SystemError) -> PlatformIdentity? {
        
        #if canImport(WinSDK)
        
        var sidSize = 0 as DWORD
        var domainSize = 0 as DWORD
        var use = SID_NAME_USE(0)
        
        name.withCString(encodedAs: UTF16.self) { namePtr in
            _ = LookupAccountNameW(nil, namePtr, nil, &sidSize, nil, &domainSize, &use)
        }
        let error = GetLastError()
        guard error == ERROR_INSUFFICIENT_BUFFER else {
            if error == ERROR_NONE_MAPPED { return .none }
            throw SystemError(code: error) ?? .init(code: .extended(.unknown))!
        }
        
        let sidBuffer = UnsafeMutableRawPointer.allocate(byteCount: Int(sidSize), alignment: MemoryLayout<UInt8>.alignment)
        let domainBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(domainSize))
        defer {
            domainBuffer.deallocate()
        }
        
        do {
            try execThrowingCFunction {
                name.withCString(encodedAs: UTF16.self) { namePtr in
                    LookupAccountNameW(nil, namePtr, sidBuffer, &sidSize, domainBuffer, &domainSize, &use)
                }
            }
        } catch let error where error.code.rawValue == DWORD(ERROR_NONE_MAPPED) {
            sidBuffer.deallocate()
            return .none
        } catch {
            sidBuffer.deallocate()
            throw error
        }
        
        return .some(.init(
            rawId: .init(unsafeOwningPSid: sidBuffer, freeingFunc: { $0.deallocate() }),
            platformKind: .init(rawValue: use)
        ))
        
        #else
        
        func queryUserIdentity(_ name: String) throws(SystemError) -> PlatformIdentity? {
            
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
                
                throw SystemError(code: error)!
                
            }
            
            guard result != nil else { return nil }
            
            return PlatformIdentity(rawId: pwd.pw_uid, platformKind: .user)
            
        }
        
        func queryGroupIdentity(_ name: String) throws(SystemError) -> PlatformIdentity? {
            
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
                
                throw SystemError(code: error)!
                
            }
            
            guard result != nil else { return nil }
            
            return PlatformIdentity(rawId: grp.gr_gid, platformKind: .group)
            
        }
        
        switch resolvePreference {
            case .preferUser:
                if let id = try queryUserIdentity(name) {
                    return id
                } else if let id = try queryGroupIdentity(name) {
                    return id
                } else {
                    return nil
                }
            case .preferGroup:
                if let id = try queryGroupIdentity(name) {
                    return id
                } else if let id = try queryUserIdentity(name) {
                    return id
                } else {
                    return nil
                }
        }
        
        #endif
        
    }


    package static func currentIdentity() throws(SystemError) -> PlatformIdentity {

        #if canImport(WinSDK)

        let tokenUserPtr = try WindowsProcessToken.current().getUser()

        // Ths SID in the tokenUserPtr is owned by that value, so we need to first copy it out 

        let sidSize = GetLengthSid(tokenUserPtr.pointee.User.Sid)
        let copiedSidBuffer = UnsafeMutableRawPointer.allocate(byteCount: Int(sidSize), alignment: MemoryLayout<SID>.alignment)
        copiedSidBuffer.copyMemory(from: tokenUserPtr.pointee.User.Sid, byteCount: Int(sidSize))

        return .init(rawId: .init(unsafeOwningPSid: copiedSidBuffer, freeingFunc: { $0.deallocate() }), platformKind: .user)

        #else 

        let uid = getuid()
        return PlatformIdentity(rawId: uid, platformKind: .user)

        #endif
    
    }


    #if canImport(WinSDK)
    package static func effectiveAccessMask(
        for identity: PlatformIdentity, 
        whenAccessing securityDescriptor: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(SystemError) -> WindowsAccessMask {
        
        var authResourceManager = nil as AUTHZ_RESOURCE_MANAGER_HANDLE?
        try execThrowingCFunction {
            AuthzInitializeResourceManager(
                DWORD(AUTHZ_RM_FLAG_NO_AUDIT), 
                nil, nil, nil, nil, 
                &authResourceManager
            )
        }
        guard let authResourceManager else {
            try SystemError.assertError(fallbackToUnknownError: true)
        }
        defer { AuthzFreeResourceManager(authResourceManager) }

        var authClientContext = nil as AUTHZ_CLIENT_CONTEXT_HANDLE?
        try execThrowingCFunction {
            AuthzInitializeContextFromSid(0, identity.rawId.psid.unsafeResourcePtr, authResourceManager, nil, LUID(), nil, &authClientContext)
        } 
        guard let authClientContext else {
            try SystemError.assertError(fallbackToUnknownError: true)
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
                    return AuthzAccessCheck(0, authClientContext, &request, nil, securityDescriptor.psd.unsafelyCastedMutableRawPtr, nil, 0, &reply, nil)
                }
            }
        }

        guard error == SystemError.successCode else {
            throw SystemError(code: error)!
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
    #endif 

}
