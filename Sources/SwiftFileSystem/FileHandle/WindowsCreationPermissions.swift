#if canImport(WinSDK)

import FileSystemCore



package enum WindowsCreationPermissions: ~Escapable {
    case inheritFromParent
    case posix(FilePermissions)
    case securityDescriptor(WindowsSecurityDescriptorView)

    @_lifetime(immortal)
    package init(_ permissions: FilePermissions?) {
        if let permissions {
            self = .posix(permissions)
        } else {
            self = .inheritFromParent
        }
    }

    @_lifetime(copy securityDescriptor)
    package init(_ securityDescriptor: WindowsSecurityDescriptorView?) {
        if let securityDescriptor {
            self = .securityDescriptor(securityDescriptor)
        } else {
            self = .inheritFromParent
        }
    }
}

#endif
