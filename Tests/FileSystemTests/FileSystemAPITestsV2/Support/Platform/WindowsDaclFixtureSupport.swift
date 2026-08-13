#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



/// DACL fixture construction for copy tests.
///
/// Unlike the copy implementation, fixtures may use the propagating
/// `SetNamedSecurityInfoW`: running the auto-inheritance algorithm is how ACL editors
/// (`Set-Acl`, Explorer) modify real security descriptors, keeping them in
/// auto-inherited mode with the entries in canonical order.
///
/// NOTE (surveyed on the Windows test machine): freshly created items are *always*
/// auto-inherited with every inherited ACE marked `INHERITED_ACE`, regardless of the
/// creation path (`CreateFileW`, `fopen`, Foundation, cmd, PowerShell). Legacy-mode
/// SDs — no `SE_DACL_AUTO_INHERITED` — only arise from non-propagating DACL writes
/// (`SetFileSecurityW`/`SetKernelObjectSecurity` without the auto-inherit request
/// bits) or from items created inside such a directory.
extension FileSystemTestSupport {

    /// Merges `entry` into the item's DACL through the propagating API, keeping the
    /// security descriptor in canonical auto-inherited form.
    static func addWindowsDaclEntry(
        _ entry: WindowsExplicitAccess,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        var descriptor = try FileSystem()
            .getSecurityInfo(forItemAt: path, querying: .dacl, followSymlink: false)
            .makeAbsolute()
        descriptor.addDaclEntries([entry])
        guard let dacl = descriptor.takeDacl() else {
            try #require(Bool(false), "The item has no DACL", sourceLocation: sourceLocation)
            return
        }
        try writeWindowsDaclPropagating(dacl, at: path, sourceLocation: sourceLocation)
    }


    /// Writes the DACL through the propagating `SetNamedSecurityInfoW`. Fixture-only:
    /// the copy implementation deliberately never uses propagating APIs.
    static func writeWindowsDaclPropagating(
        _ dacl: borrowing WindowsRawAcl,
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let result = dacl.withUnsafePACL { daclPointer in
            path.withPlatformString { pathPointer in
                SetNamedSecurityInfoW(
                    UnsafeMutablePointer(mutating: pathPointer),
                    SE_FILE_OBJECT,
                    DWORD(DACL_SECURITY_INFORMATION),
                    nil,
                    nil,
                    daclPointer,
                    nil
                )
            }
        }
        try #require(result == ERROR_SUCCESS, sourceLocation: sourceLocation)
    }


    /// Installs a present-but-NULL DACL with the protected bit — the
    /// "everyone has full access" shape.
    static func applyWindowsNullProtectedDacl(
        at path: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(READ_CONTROL) | DWORD(WRITE_DAC),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_FLAG_BACKUP_SEMANTICS) | DWORD(FILE_FLAG_OPEN_REPARSE_POINT),
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }

        let securityInformation = DWORD(DACL_SECURITY_INFORMATION)
            | DWORD(PROTECTED_DACL_SECURITY_INFORMATION)
        let result = SetSecurityInfo(
            handle,
            SE_FILE_OBJECT,
            securityInformation,
            nil,
            nil,
            nil,
            nil
        )
        try #require(result == ERROR_SUCCESS, sourceLocation: sourceLocation)
    }


    /// The SDDL form of the item's security descriptor, for exact comparisons.
    static func windowsSddlString(
        ofItemAt path: FilePath,
        querying members: FileOperationOptions.WindowsSecurityInfoMembers = .dacl,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> String {
        var desiredAccess = DWORD(READ_CONTROL)
        if members.contains(.sacl) {
            desiredAccess |= DWORD(ACCESS_SYSTEM_SECURITY)
        }
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                desiredAccess,
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                DWORD(FILE_FLAG_BACKUP_SEMANTICS) | DWORD(FILE_FLAG_OPEN_REPARSE_POINT),
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }

        var descriptor = nil as PSECURITY_DESCRIPTOR?
        let queryResult = GetSecurityInfo(
            handle,
            SE_FILE_OBJECT,
            members.rawValue,
            nil,
            nil,
            nil,
            nil,
            &descriptor
        )
        try #require(queryResult == ERROR_SUCCESS, sourceLocation: sourceLocation)
        try #require(descriptor != nil, sourceLocation: sourceLocation)
        defer { LocalFree(descriptor) }

        var stringPointer = nil as LPWSTR?
        var stringLength = ULONG(0)
        let conversionResult = ConvertSecurityDescriptorToStringSecurityDescriptorW(
            descriptor,
            DWORD(SDDL_REVISION_1),
            members.rawValue,
            &stringPointer,
            &stringLength
        )
        try #require(conversionResult, sourceLocation: sourceLocation)
        let sddl = try #require(stringPointer, sourceLocation: sourceLocation)
        defer { LocalFree(sddl) }
        return String(decodingCString: sddl, as: UTF16.self)
    }

}

#endif
