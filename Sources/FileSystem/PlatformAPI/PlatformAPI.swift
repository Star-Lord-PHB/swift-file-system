import PlatformCLib


public final class PlatformAPI: PlatformAPIProtocol {

    public init() { }

}



extension PlatformAPI {

    public func accountName(for identity: PlatformIdentity) throws(FileError) -> String? {

        #if canImport(WinSDK)

        #warning("Not Implemented yet")
        throw FileError.init(code: .extended(.notImplemented), operationDescription: .closingHandle(at: FilePath))

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
    public func identity(forAccountName name: String) throws(FileError) -> PlatformIdentity {

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

        #warning("Not Implemented yet")
        throw FileError.init(code: .extended(.notImplemented), operationDescription: .queryingCurrentIdentity())

        #else 

        let uid = getuid()
        return PlatformIdentity(rawId: uid, kind: .user)

        #endif
    
    }

}