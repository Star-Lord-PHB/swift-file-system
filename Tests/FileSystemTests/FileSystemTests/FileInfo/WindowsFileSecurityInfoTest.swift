#if canImport(WinSDK)
import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore

import CFileSystem



extension FileSystemTest {

    fileprivate static var byNameFileInfoAvailable: Bool { getGetFileInformationByNameFuncPtr() != nil }

    @Suite
    final class WindowsFileSecurityInfoTest: FSIsolatedTestCase {

        func getEffectiveAccessMask(forItemAt path: FilePath) throws -> ACCESS_MASK {
            let getFileInfoByNameFuncPtr = try #require(getGetFileInformationByNameFuncPtr(), "GetFileInformationByName is not available on this version of Windows")
            var info = FILE_STAT_INFORMATION()
            let success = path.withPlatformString { pathPtr in
                getFileInfoByNameFuncPtr(pathPtr, FileStatByNameInfo, &info, DWORD(MemoryLayout<FILE_STAT_INFORMATION>.size))
            }.boolValue
            try #require(success, "Fail to get Effective Access Mask of file at \(path)")
            return info.EffectiveAccess
        }

    }

}



extension FileSystemTest.WindowsFileSecurityInfoTest {

    @Test("Getting Security Descriptor and Effective Access Mask", .enabled(if: FileSystemTest.byNameFileInfoAvailable))
    func gettingSecurityDescriptorAndEffectiveAccessMask() async throws {

        // Comparisons here are based on effective access masks only, so they do not guarantee
        // full correctness. (Well, I can't really think of any better way to verify them automatically right now...)
        
        let filePath = try makeFile(at: "file") 

        let sd = try FileSystem().getSecurityInfo(forItemAt: filePath)
        let effectiveAccessMask = try PlatformAPI().effectiveAccessMaskForCurrentProcess(whenAccessing: sd)

        let expectedEffectiveAccessMask = try getEffectiveAccessMask(forItemAt: filePath)

        #expect(effectiveAccessMask.rawValue == expectedEffectiveAccessMask)

    }


    @Test("Setting Security Descriptor")
    func settingSecurityDescriptor() async throws {
        
        let filePath = try makeFile(at: "file")

        let trustee = WindowsExplicitAccess.RawTrustee.everyone

        let newSecurity = WindowsRawAcl(entries: [
            .init(
                permission: [.readData, .writeData, .appendData, .execute, .traverse, .synchronize], 
                accessMode: .grantAccess, 
                trustee: trustee
            ),
            .init(
                permission: [.readControl, .readAttributes, .writeDAC, .writeAttributes], 
                accessMode: .denyAccess,
                trustee: trustee
            )
        ])

        try FileSystem().setSecurityInfo(forItemAt: filePath, dacl: .replace(newSecurity))

        let sd = try FileSystem().getSecurityInfo(forItemAt: filePath)
        
        try #require(sd.dacl.case == .present, "DACL is nil after setting new security descriptor")

        let dacl = sd.dacl.value!
        
        let hasFirstSetAce = dacl.first { ace in 
            !ace.flags.contains(.inherited) 
                && ace.type == .allow
                && ace.permission.sid == trustee.sid.view
                && ace.permission.mask == [.readData, .writeData, .appendData, .execute, .traverse, .synchronize]
        } != nil

        #expect(hasFirstSetAce, "DACL does not contain the first ACE being set")

        let hasSecondSetAce = dacl.first { ace in 
            !ace.flags.contains(.inherited) 
                && ace.type == .deny
                && ace.permission.sid == trustee.sid.view
                && ace.permission.mask == [.readControl, .readAttributes, .writeDAC, .writeAttributes]
        } != nil

        #expect(hasSecondSetAce, "DACL does not contain the second ACE being set")

    }

}
#endif 