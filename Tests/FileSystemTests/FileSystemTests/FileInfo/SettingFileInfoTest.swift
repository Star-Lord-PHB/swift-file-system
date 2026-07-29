import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore


extension FileSystemTest {

    final class SettingFileInfoTests: FSIsolatedTestCase {}

}



extension FileSystemTest.SettingFileInfoTests {

    @Test("Setting File Times")
    func settingFileTimes() async throws {
        
        let access = FileTimeSpec(seconds: 1768080340, nanoseconds: 100_000)
        let modification = FileTimeSpec(seconds: 1766713392, nanoseconds: 200_000)
        let creation = FileTimeSpec(seconds: 1766588640, nanoseconds: 300_000)

        let filePath = try makeFile(at: "file")

        try FileSystem().setTimes(
            forItemAt: filePath,
            accessTime: access,
            modificationTime: modification,
            creationTime: creation
        )

        let fileAttrs = try FileManager.default.attributesOfItem(atPath: filePath.string)
        let newAccessDate = try accessTime(ofItemAt: filePath)

        #expect(newAccessDate == access.date)
        #expect(fileAttrs[.modificationDate] as? Date == modification.date)

        #if !(canImport(Musl) || canImport(Glibc))
        #expect(fileAttrs[.creationDate] as? Date == creation.date)
        #endif 

    }


    @Test("Setting Dir Times")
    func settingDirTimes() async throws {
        
        let access = FileTimeSpec(seconds: 1768080340, nanoseconds: 100_000)
        let modification = FileTimeSpec(seconds: 1766713392, nanoseconds: 200_000)
        let creation = FileTimeSpec(seconds: 1766588640, nanoseconds: 300_000)

        let dirPath = try makeDir(at: "dir")

        try FileSystem().setTimes(
            forItemAt: dirPath,
            accessTime: access,
            modificationTime: modification,
            creationTime: creation
        )

        let newAttrs = try FileManager.default.attributesOfItem(atPath: dirPath.string)
        let newAccessDate = try accessTime(ofItemAt: dirPath)

        #expect(newAccessDate == access.date)
        #expect(newAttrs[.modificationDate] as? Date == modification.date)

        #if !(canImport(Musl) || canImport(Glibc))
        #expect(newAttrs[.creationDate] as? Date == creation.date)
        #endif 

    }


    @Test("Setting Symlink Times")
    func settingSymlinkTimes() async throws {
        
        let access = FileTimeSpec(seconds: 1768080340, nanoseconds: 100_000)
        let modification = FileTimeSpec(seconds: 1766713392, nanoseconds: 200_000)
        let creation = FileTimeSpec(seconds: 1766588640, nanoseconds: 300_000)

        let targetPath = try makeFile(at: "target")
        let symlinkPath = try makeSymlink(at: "symlink", pointingTo: "./target")

        let targetExpectation = try ItemExpectation.from(itemAt: targetPath)

        try FileSystem().setTimes(
            forItemAt: symlinkPath,
            accessTime: access,
            modificationTime: modification,
            creationTime: creation,
            followSymlink: false
        )

        let newAttrs = try FileManager.default.attributesOfItem(atPath: symlinkPath.string)
        let newAccessDate = try accessTime(ofItemAt: symlinkPath)

        #if canImport(Glibc) || canImport(Musl)
        withKnownIssue("On Linux, the URLResourceValues for symlink will modify the access time, causing the result to be unreliable") {
            #expect(newAccessDate == access.date)    
        }
        #else
        #expect(newAccessDate == access.date)
        #endif 
        
        #expect(newAttrs[.modificationDate] as? Date == modification.date)

        #if !(canImport(Musl) || canImport(Glibc))
        #expect(newAttrs[.creationDate] as? Date == creation.date)
        #endif 

        try expectItem(at: targetPath, toMatch: targetExpectation)      // Ensure that the target file is not influenced

    }


    @Test("Setting File Attributes")
    func settingFileAttributes() async throws {
        
        #if canImport(WinSDK)
        let attr = [.currentPlatform.isHidden, .currentPlatform.isReadOnly] as PlatformFileAttributes
        #elseif canImport(Darwin)
        let attr = [.currentPlatform.noDump, .currentPlatform.isHidden] as PlatformFileAttributes
        #elseif os(FreeBSD)
        let attr = [.currentPlatform.noDump, .currentPlatform.isHidden] as PlatformFileAttributes
        #elseif os(OpenBSD)
        let attr = [.currentPlatform.noDump] as PlatformFileAttributes
        #elseif canImport(Glibc) || canImport(Musl)
        let attr = [.currentPlatform.noDump] as PlatformFileAttributes
        #else 
        try Test.cancel("Platform without current file attribute support")
        #endif 

        let filePath = try makeFile(at: "file")

        try FileSystem().setAttributes(forItemAt: filePath, attributes: attr)

        let fileInfo = try FileInfo(fileAt: filePath, followSymLink: false)

        #expect(fileInfo.attributes == attr)

    }


    @Test("Setting Dir Attributes")
    func settingDirAttributes() async throws {
        
        #if canImport(WinSDK)
        let attr = [.currentPlatform.isHidden, .currentPlatform.isReadOnly] as PlatformFileAttributes
        #elseif canImport(Darwin)
        let attr = [.currentPlatform.noDump, .currentPlatform.isHidden] as PlatformFileAttributes
        #elseif os(FreeBSD)
        let attr = [.currentPlatform.noDump, .currentPlatform.isHidden] as PlatformFileAttributes
        #elseif os(OpenBSD)
        let attr = [.currentPlatform.noDump] as PlatformFileAttributes
        #elseif canImport(Glibc) || canImport(Musl)
        let attr = [.currentPlatform.noDump] as PlatformFileAttributes
        #else 
        try Test.cancel("Platform without current file attribute support")
        #endif 

        let dirPath = try makeDir(at: "dir")

        try FileSystem().setAttributes(forItemAt: dirPath, attributes: attr)

        let dirInfo = try FileInfo(fileAt: dirPath, followSymLink: false)

        #if canImport(WinSDK)
        #expect(dirInfo.attributes == attr.union(.currentPlatform.isDirectory))
        #else 
        #expect(dirInfo.attributes == attr)
        #endif 

    }


    @Test("Setting Symlink Attributes")
    func settingSymlinkAttributes() async throws {
        
        #if canImport(WinSDK)
        let attr = [.currentPlatform.isHidden, .currentPlatform.isReadOnly] as PlatformFileAttributes
        #elseif canImport(Darwin)
        let attr = [.currentPlatform.noDump, .currentPlatform.isHidden] as PlatformFileAttributes
        #elseif os(FreeBSD)
        let attr = [.currentPlatform.noDump, .currentPlatform.isHidden] as PlatformFileAttributes
        #elseif os(OpenBSD)
        let attr = [.currentPlatform.noDump] as PlatformFileAttributes
        #elseif canImport(Glibc) || canImport(Musl)
        let attr = [.currentPlatform.noDump] as PlatformFileAttributes
        #else 
        try Test.cancel("Platform without current file attribute support")
        #endif 

        let targetPath = try makeFile(at: "target")
        let symlinkPath = try makeSymlink(at: "symlink", pointingTo: "./target")

        let targetExpectation = try ItemExpectation.from(itemAt: targetPath)

        #if canImport(Glibc) || canImport(Musl)

        // On linux, setting attributes for symlink is not supported and will fail with ELOOP

        let linkExpectation = try ItemExpectation.from(itemAt: symlinkPath, followSymlink: false)

        let error = #expect(throws: PlatformError.self) {
            try FileSystem().setAttributes(forItemAt: symlinkPath, attributes: attr, followSymlink: false)
        }

        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)
        try expectItem(at: symlinkPath, toMatch: linkExpectation)

        #else 

        // On other platforms, setting attributes for symlink is supported

        try FileSystem().setAttributes(forItemAt: symlinkPath, attributes: attr, followSymlink: false)

        let symlinkInfo = try FileInfo(fileAt: symlinkPath, followSymLink: false)
        #if canImport(WinSDK)
        #expect(symlinkInfo.attributes == attr.union(.windows.isReparsePoint))
        #else
        #expect(symlinkInfo.attributes == attr)
        #endif 

        #endif 

        try expectItem(at: targetPath, toMatch: targetExpectation)      // Ensure that the target file is not influenced

    }


    #if !canImport(WinSDK)
    @Test("Setting File Permissions")
    func settingFilePermissions() async throws {
        
        let permissions = [.ownerReadWriteExecute, .groupReadExecute, .setUserID] as FilePermissions

        let filePath = try makeFile(at: "file")

        try FileSystem().setPosixPermissions(forItemAt: filePath, permissions: permissions)

        let newPermissions = try #require(try FileManager.default.attributesOfItem(atPath: filePath.string)[.posixPermissions] as? Int16)

        #expect(newPermissions == permissions.rawValue)

    }


    @Test("Setting Dir Permissions")
    func settingDirPermissions() async throws {
        
        let permissions = [.ownerReadWriteExecute, .groupReadExecute, .setUserID] as FilePermissions

        let dirPath = try makeDir(at: "dir")

        try FileSystem().setPosixPermissions(forItemAt: dirPath, permissions: permissions)

        let newPermissions = try #require(try FileManager.default.attributesOfItem(atPath: dirPath.string)[.posixPermissions] as? Int16)

        #expect(newPermissions == permissions.rawValue)

    }


    @Test("Setting Symlink Permissions")
    func settingSymlinkPermissions() async throws {

        let permissions = [.ownerReadWriteExecute, .groupReadExecute, .setUserID] as FilePermissions

        let targetPath = try makeFile(at: "target")
        let symlinkPath = try makeSymlink(at: "symlink", pointingTo: "./target")

        let targetExpectation = try ItemExpectation.from(itemAt: targetPath)

        #if canImport(Glibc) || canImport(Musl)

        do {
            try FileSystem().setPosixPermissions(forItemAt: symlinkPath, permissions: permissions, followSymlink: false)
            let newPermissions = try #require(try FileManager.default.attributesOfItem(atPath: symlinkPath.string)[.posixPermissions] as? Int16)
            #expect(newPermissions == permissions.rawValue)
        } catch let error as PlatformError where error.kind == .unsupported {
            // On linux, most of the fs does not support setting permissions for symlink, so unsupported error is ignored
        }

        #else

        try FileSystem().setPosixPermissions(forItemAt: symlinkPath, permissions: permissions, followSymlink: false)
        let newPermissions = try #require(try FileManager.default.attributesOfItem(atPath: symlinkPath.string)[.posixPermissions] as? Int16)
        #expect(newPermissions == permissions.rawValue)
        
        #endif 

        try expectItem(at: targetPath, toMatch: targetExpectation)      // Ensure that the target file is not influenced

    }
    #endif 

}
