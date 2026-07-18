#if canImport(WinSDK)

import WinSDK
import SystemPackage
import Testing
import SwiftFileSystem



extension FileInfoAPITests.QueryTests {

    @Suite("Windows fields")
    struct WindowsQueryTests {

        typealias Support = FileInfoAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileInfoAPITests.QueryTests.WindowsQueryTests {

    private struct NativeInfo {
        let identifier: FileIdentifier
        let attributes: DWORD
    }


    private func nativeInfo(
        at path: FilePath,
        followSymlink: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> NativeInfo {
        let noFollowFlag = followSymlink
            ? DWORD(0)
            : DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        let openFlags = DWORD(FILE_FLAG_BACKUP_SEMANTICS) | noFollowFlag
        let handle = path.withPlatformString { pathPointer in
            CreateFileW(
                pathPointer,
                DWORD(FILE_READ_ATTRIBUTES),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil,
                DWORD(OPEN_EXISTING),
                openFlags,
                nil
            )
        }
        try #require(
            handle != INVALID_HANDLE_VALUE,
            sourceLocation: sourceLocation
        )
        defer { CloseHandle(handle) }

        var identifierInfo = FILE_ID_INFO()
        try #require(
            GetFileInformationByHandleEx(
                handle,
                FileIdInfo,
                &identifierInfo,
                DWORD(MemoryLayout<FILE_ID_INFO>.size)
            ),
            sourceLocation: sourceLocation
        )

        var basicInfo = FILE_BASIC_INFO()
        try #require(
            GetFileInformationByHandleEx(
                handle,
                FileBasicInfo,
                &basicInfo,
                DWORD(MemoryLayout<FILE_BASIC_INFO>.size)
            ),
            sourceLocation: sourceLocation
        )

        return .init(
            identifier: .init(
                fileId: identifierInfo.FileId.uint128,
                deviceId: identifierInfo.VolumeSerialNumber
            ),
            attributes: basicInfo.FileAttributes
        )
    }


    @Test
    func `Regular file fields match Win32`() throws {

        let path = try workspace.makeFile(at: "file")

        let info = try FileInfo(fileAt: path)
        let expected = try nativeInfo(at: path, followSymlink: true)

        #expect(info.fileIdentifier == expected.identifier)
        #expect(info.attributes.rawValue == expected.attributes)
        #expect(info.supportedAttributes == .all)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Directory fields match Win32`() throws {

        let path = try workspace.makeDirectory(at: "directory")

        let info = try FileInfo(fileAt: path)
        let expected = try nativeInfo(at: path, followSymlink: true)

        #expect(info.fileIdentifier == expected.identifier)
        #expect(info.attributes.rawValue == expected.attributes)
        #expect(info.supportedAttributes == .all)
        #expect(info.attributes.isSubset(of: info.supportedAttributes))

    }


    @Test
    func `Symlink fields respect follow option`() throws {

        let target = try workspace.makeFile(at: "target")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let followedInfo = try FileInfo(fileAt: link, followSymLink: true)
        let directInfo = try FileInfo(fileAt: link, followSymLink: false)
        let followedExpected = try nativeInfo(at: link, followSymlink: true)
        let directExpected = try nativeInfo(at: link, followSymlink: false)

        #expect(followedInfo.fileIdentifier == followedExpected.identifier)
        #expect(followedInfo.attributes.rawValue == followedExpected.attributes)
        #expect(followedInfo.supportedAttributes == .all)
        #expect(followedInfo.attributes.isSubset(of: followedInfo.supportedAttributes))

        #expect(directInfo.fileIdentifier == directExpected.identifier)
        #expect(directInfo.attributes.rawValue == directExpected.attributes)
        #expect(directInfo.supportedAttributes == .all)
        #expect(directInfo.attributes.isSubset(of: directInfo.supportedAttributes))

    }

}

#endif
