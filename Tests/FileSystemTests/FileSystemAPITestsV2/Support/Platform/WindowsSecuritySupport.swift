#if canImport(WinSDK)

import WinSDK
import Testing
import SwiftFileSystem



extension FileSystemTestSupport {

    enum WindowsAclState: Equatable, Sendable {
        case absent
        case null
        case acl
    }


    struct WindowsAceSnapshot: Equatable, Sendable {
        let type: BYTE
        let flags: BYTE
        let size: WORD
        let bytes: [UInt8]
    }


    struct WindowsAclSnapshot: Equatable, Sendable {
        let state: WindowsAclState
        let defaulted: Bool?
        let revision: BYTE?
        let aces: [WindowsAceSnapshot]
    }


    struct WindowsSecuritySnapshot: Equatable, Sendable {
        let revision: DWORD
        let control: SECURITY_DESCRIPTOR_CONTROL
        let owner: WindowsSid?
        let ownerDefaulted: Bool?
        let group: WindowsSid?
        let groupDefaulted: Bool?
        let dacl: WindowsAclSnapshot
        let sacl: WindowsAclSnapshot
    }

}



extension FileSystemTestSupport {

    static func captureWindowsSecuritySnapshot(
        at path: FilePath,
        querying members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl,
        followSymlink: Bool = false,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> WindowsSecuritySnapshot {
        var desiredAccess = DWORD(READ_CONTROL)
        if members.contains(.sacl) {
            desiredAccess |= DWORD(ACCESS_SYSTEM_SECURITY)
        }

        let noFollowFlag = followSymlink
            ? DWORD(0)
            : DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        let openFlags = DWORD(FILE_FLAG_BACKUP_SEMANTICS) | noFollowFlag
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                desiredAccess,
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                openFlags,
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }

        var descriptor = nil as PSECURITY_DESCRIPTOR?
        let result = GetSecurityInfo(
            handle,
            SE_FILE_OBJECT,
            members.rawValue,
            nil,
            nil,
            nil,
            nil,
            &descriptor
        )
        try #require(result == ERROR_SUCCESS, sourceLocation: sourceLocation)
        try #require(descriptor != nil, sourceLocation: sourceLocation)
        defer { LocalFree(descriptor) }

        return try parseWindowsSecurityDescriptor(
            descriptor!,
            sourceLocation: sourceLocation
        )
    }


    static func parseWindowsSecurityDescriptor(
        _ descriptor: borrowing WindowsSelfRelativeSecurityDescriptor,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> WindowsSecuritySnapshot {
        try descriptor.withUnsafeSdPtr { descriptorPointer in
            try parseWindowsSecurityDescriptor(
                descriptorPointer,
                sourceLocation: sourceLocation
            )
        }
    }


    static func parseWindowsRawAcl(
        _ acl: borrowing WindowsRawAcl,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> WindowsAclSnapshot {
        try acl.withUnsafePACL { aclPointer in
            try capturePresentWindowsAcl(
                aclPointer,
                defaulted: false,
                sourceLocation: sourceLocation
            )
        }
    }


    static func setProtectedNativeWindowsDacl(
        _ dacl: borrowing WindowsRawAcl,
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let noFollowFlag = followSymlink
            ? DWORD(0)
            : DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        let openFlags = DWORD(FILE_FLAG_BACKUP_SEMANTICS) | noFollowFlag
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(READ_CONTROL) | DWORD(WRITE_DAC),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                openFlags,
                nil
            )
        }
        try #require(handle != INVALID_HANDLE_VALUE, sourceLocation: sourceLocation)
        defer { CloseHandle(handle) }

        let securityInformation = DWORD(DACL_SECURITY_INFORMATION)
            | DWORD(PROTECTED_DACL_SECURITY_INFORMATION)
        let result = dacl.withUnsafePACL { daclPointer in
            SetSecurityInfo(
                handle,
                SE_FILE_OBJECT,
                securityInformation,
                nil,
                nil,
                daclPointer,
                nil
            )
        }
        try #require(result == ERROR_SUCCESS, sourceLocation: sourceLocation)
    }

}



extension FileSystemTestSupport {

    static func expectWindowsSecurity(
        _ actual: WindowsSecuritySnapshot,
        matches expected: WindowsSecuritySnapshot,
        comparing members: FileOperationOptions.WindowsSecurityInfoMembers = .allExceptSacl,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(actual.revision == expected.revision, sourceLocation: sourceLocation)
        #expect(actual.control == expected.control, sourceLocation: sourceLocation)

        if members.contains(.owner) {
            #expect(actual.owner == expected.owner, sourceLocation: sourceLocation)
            #expect(
                actual.ownerDefaulted == expected.ownerDefaulted,
                sourceLocation: sourceLocation
            )
            #expect(actual.owner != nil, sourceLocation: sourceLocation)
        } else {
            #expect(actual.owner == nil, sourceLocation: sourceLocation)
            #expect(actual.ownerDefaulted == nil, sourceLocation: sourceLocation)
        }
        if members.contains(.group) {
            #expect(actual.group == expected.group, sourceLocation: sourceLocation)
            #expect(
                actual.groupDefaulted == expected.groupDefaulted,
                sourceLocation: sourceLocation
            )
            #expect(actual.group != nil, sourceLocation: sourceLocation)
        } else {
            #expect(actual.group == nil, sourceLocation: sourceLocation)
            #expect(actual.groupDefaulted == nil, sourceLocation: sourceLocation)
        }
        if members.contains(.dacl) {
            expectWindowsAcl(
                actual.dacl,
                matches: expected.dacl,
                sourceLocation: sourceLocation
            )
            #expect(actual.dacl.state != .absent, sourceLocation: sourceLocation)
        } else {
            #expect(actual.dacl.state == .absent, sourceLocation: sourceLocation)
        }
        if members.contains(.sacl) {
            expectWindowsAcl(
                actual.sacl,
                matches: expected.sacl,
                sourceLocation: sourceLocation
            )
        } else {
            #expect(actual.sacl.state == .absent, sourceLocation: sourceLocation)
        }
    }


    static func expectWindowsSecurity(
        _ actual: ItemMetadata.Security,
        matches expected: ItemMetadata.Security,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        expectWindowsSecurity(
            actual.windowsSnapshot,
            matches: expected.windowsSnapshot,
            sourceLocation: sourceLocation
        )
    }


    static func expectWindowsAcl(
        _ actual: WindowsAclSnapshot,
        matches expected: WindowsAclSnapshot,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(actual.state == expected.state, sourceLocation: sourceLocation)
        #expect(actual.defaulted == expected.defaulted, sourceLocation: sourceLocation)
        #expect(actual.revision == expected.revision, sourceLocation: sourceLocation)
        #expect(actual.aces.count == expected.aces.count, sourceLocation: sourceLocation)

        let aceCount = min(actual.aces.count, expected.aces.count)
        for index in 0 ..< aceCount {
            let actualAce = actual.aces[index]
            let expectedAce = expected.aces[index]
            let comment = "ACE at index \(index)" as Comment
            #expect(
                actualAce.type == expectedAce.type,
                comment,
                sourceLocation: sourceLocation
            )
            #expect(
                actualAce.flags == expectedAce.flags,
                comment,
                sourceLocation: sourceLocation
            )
            #expect(
                actualAce.size == expectedAce.size,
                comment,
                sourceLocation: sourceLocation
            )
            #expect(
                actualAce.bytes == expectedAce.bytes,
                comment,
                sourceLocation: sourceLocation
            )
        }
    }

}



extension FileSystemTestSupport {

    private enum RawWindowsAclType {
        case dacl
        case sacl
    }


    private static func parseWindowsSecurityDescriptor(
        _ descriptor: PSECURITY_DESCRIPTOR,
        sourceLocation: SourceLocation
    ) throws -> WindowsSecuritySnapshot {
        try #require(
            IsValidSecurityDescriptor(descriptor),
            sourceLocation: sourceLocation
        )

        var control = 0 as SECURITY_DESCRIPTOR_CONTROL
        var revision = DWORD(0)
        try #require(
            GetSecurityDescriptorControl(descriptor, &control, &revision),
            sourceLocation: sourceLocation
        )

        var ownerPointer = nil as PSID?
        var ownerDefaulted = false as WindowsBool
        try #require(
            GetSecurityDescriptorOwner(
                descriptor,
                &ownerPointer,
                &ownerDefaulted
            ),
            sourceLocation: sourceLocation
        )
        let owner = try ownerPointer.map { ownerPointer in
            try copyWindowsSid(ownerPointer, sourceLocation: sourceLocation)
        }

        var groupPointer = nil as PSID?
        var groupDefaulted = false as WindowsBool
        try #require(
            GetSecurityDescriptorGroup(
                descriptor,
                &groupPointer,
                &groupDefaulted
            ),
            sourceLocation: sourceLocation
        )
        let group = try groupPointer.map { groupPointer in
            try copyWindowsSid(groupPointer, sourceLocation: sourceLocation)
        }

        return WindowsSecuritySnapshot(
            revision: revision,
            control: control,
            owner: owner,
            ownerDefaulted: owner == nil ? nil : ownerDefaulted.boolValue,
            group: group,
            groupDefaulted: group == nil ? nil : groupDefaulted.boolValue,
            dacl: try captureWindowsAcl(
                fromRawDescriptor: descriptor,
                type: .dacl,
                sourceLocation: sourceLocation
            ),
            sacl: try captureWindowsAcl(
                fromRawDescriptor: descriptor,
                type: .sacl,
                sourceLocation: sourceLocation
            )
        )
    }


    private static func captureWindowsAcl(
        fromRawDescriptor descriptor: PSECURITY_DESCRIPTOR,
        type: RawWindowsAclType,
        sourceLocation: SourceLocation
    ) throws -> WindowsAclSnapshot {
        var aclPointer = nil as PACL?
        var aclPresent = false as WindowsBool
        var aclDefaulted = false as WindowsBool

        switch type {
            case .dacl:
                try #require(
                    GetSecurityDescriptorDacl(
                        descriptor,
                        &aclPresent,
                        &aclPointer,
                        &aclDefaulted
                    ),
                    sourceLocation: sourceLocation
                )
            case .sacl:
                try #require(
                    GetSecurityDescriptorSacl(
                        descriptor,
                        &aclPresent,
                        &aclPointer,
                        &aclDefaulted
                    ),
                    sourceLocation: sourceLocation
                )
        }

        guard aclPresent.boolValue else {
            return WindowsAclSnapshot(
                state: .absent,
                defaulted: nil,
                revision: nil,
                aces: []
            )
        }
        guard let aclPointer else {
            return WindowsAclSnapshot(
                state: .null,
                defaulted: aclDefaulted.boolValue,
                revision: nil,
                aces: []
            )
        }
        return try capturePresentWindowsAcl(
            aclPointer,
            defaulted: aclDefaulted.boolValue,
            sourceLocation: sourceLocation
        )
    }


    private static func capturePresentWindowsAcl(
        _ aclPointer: PACL,
        defaulted: Bool,
        sourceLocation: SourceLocation
    ) throws -> WindowsAclSnapshot {
        try #require(IsValidAcl(aclPointer), sourceLocation: sourceLocation)

        var information = ACL_SIZE_INFORMATION()
        try #require(
            GetAclInformation(
                aclPointer,
                &information,
                DWORD(MemoryLayout<ACL_SIZE_INFORMATION>.size),
                AclSizeInformation
            ),
            sourceLocation: sourceLocation
        )

        var aces = [WindowsAceSnapshot]()
        aces.reserveCapacity(Int(information.AceCount))
        for index in 0 ..< information.AceCount {
            var acePointer = nil as LPVOID?
            try #require(
                GetAce(aclPointer, index, &acePointer),
                sourceLocation: sourceLocation
            )
            try #require(acePointer != nil, sourceLocation: sourceLocation)
            let header = acePointer!.assumingMemoryBound(to: ACE_HEADER.self).pointee
            let bytes = Array(
                UnsafeRawBufferPointer(
                    start: acePointer,
                    count: Int(header.AceSize)
                )
            )
            aces.append(
                WindowsAceSnapshot(
                    type: header.AceType,
                    flags: header.AceFlags,
                    size: header.AceSize,
                    bytes: bytes
                )
            )
        }

        return WindowsAclSnapshot(
            state: .acl,
            defaulted: defaulted,
            revision: aclPointer.pointee.AclRevision,
            aces: aces
        )
    }

}

#endif
