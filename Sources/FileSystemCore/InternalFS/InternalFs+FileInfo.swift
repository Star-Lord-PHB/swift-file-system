import PlatformCLib
import CFileSystem
import SystemPackage



extension InternalFS {
    
    package static func ustat(_ path: FilePath) throws(LowLevelError) -> PlatformInteropTypes.Stat {
        
        var st = PlatformInteropTypes.Stat.PlatformStat()
        
        #if canImport(WinSDK)
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                _stat64(pathPtr, &st)
            }
        }
        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                stat(pathPtr, &st)
            }
        }
        #else
        try execThrowingCFunction {
            path.withPlatformString { pathStr in
                systemStatCompat(pathStr, 0, &st)
            }
        }
        #endif
        
        return .init(platformStat: st)
        
    }
    
    
    #if !canImport(WinSDK)
    package static func ulstat(_ path: FilePath) throws(LowLevelError) -> PlatformInteropTypes.Stat {
        
        var st = PlatformInteropTypes.Stat.PlatformStat()
        
        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        try execThrowingCFunction {
            path.withPlatformString { pathPtr in
                lstat(pathPtr, &st)
            }
        }
        #else
        try execThrowingCFunction {
            systemStatCompat(path.string, AT_SYMLINK_NOFOLLOW, &st)
        }
        #endif
        
        return .init(platformStat: st)
        
    }
    #endif
    

    package static func getFileInfo(forItemAt path: FilePath, followSymlink: Bool) throws(LowLevelError) -> FileInfo {

        #if canImport(WinSDK)

        if let GetFileInformationByNameFuncPtr = getGetFileInformationByNameFuncPtr() {

            // A faster path for getting information of files without opening a handle

            var infoByName = FILE_STAT_BASIC_INFORMATION()

            try execThrowingCFunction {
                path.withPlatformString { pathPtr in 
                    GetFileInformationByNameFuncPtr(pathPtr, FileStatBasicByNameInfo, &infoByName, DWORD(MemoryLayout<FILE_STAT_BASIC_INFORMATION>.size)).boolValue
                }
            }

            if !followSymlink || infoByName.ReparseTag != IO_REPARSE_TAG_SYMLINK {

                let type = if infoByName.ReparseTag == IO_REPARSE_TAG_SYMLINK {
                    .symlink
                } else if (infoByName.FileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    .directory
                } else {
                    .regular
                } as FileKind

                return .init(
                    size: .init(infoByName.EndOfFile.QuadPart), 
                    type: type,
                    times: .init(
                        lastAccess: .init(platformFileTime: infoByName.LastAccessTime), 
                        lastModification: .init(platformFileTime: infoByName.LastWriteTime), 
                        lastChange: .init(platformFileTime: infoByName.ChangeTime), 
                        creation: .init(platformFileTime: infoByName.CreationTime)
                    ), 
                    fileIdentifier: .init(fileId: infoByName.FileId128.uint128, deviceId: .init(infoByName.VolumeSerialNumber.QuadPart)), 
                    attributes: .init(rawValue: infoByName.FileAttributes), 
                    supportedAttributes: .all
                )

            }

            // if following symlink is required and the item is a symlink, fall back to use handle-based method

        }

        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: !followSymlink, platformSpecificOptions: .windows.backupSemantics)
        )

        return try handle.fileInfo()

        #else 

        let st = if followSymlink {
            try ustat(path)
        } else {
            try ulstat(path)
        }

        return .init(stat: st)

        #endif 

    }

}



// - MARK: File Type
extension InternalFS {

    package static func type(ofItemAt path: FilePath) throws(LowLevelError) -> FileKind {
        
        #if canImport(WinSDK)

        if let GetFileInformationByNameFuncPtr = getGetFileInformationByNameFuncPtr() {

            // A faster path for getting information of files without opening a handle

            var infoByName = FILE_STAT_BASIC_INFORMATION()

            do {
                try execThrowingCFunction {
                    path.withPlatformString { pathPtr in 
                        GetFileInformationByNameFuncPtr(pathPtr, FileStatBasicByNameInfo, &infoByName, DWORD(MemoryLayout<FILE_STAT_BASIC_INFORMATION>.size)).boolValue
                    }
                }

                return if infoByName.ReparseTag == IO_REPARSE_TAG_SYMLINK {
                    .symlink
                } else if (infoByName.FileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY)) != 0 {
                    .directory
                } else {
                    .regular
                }
            } catch let e where e.kind == .notFound || e.kind == .nameTooLong || e.code == .invalidFileName {
                // These errors are won't be resolved even after falling back to handle-based method
                // MARK: TODO: Need to check whether there are other error codes like these
                throw e
            } catch {
                // Fallback to handle-based method
            }

        }

        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: true, platformSpecificOptions: .windows.backupSemantics)
        )

        return try handle.type()

        #else 

        return .init(mode: try ulstat(path).st_mode)

        #endif

    }

}



// MARK: - Times
extension InternalFS {
    
    #if !canImport(WinSDK)
    private static func utimens(for path: FilePath, times: (FileTimeSpec, FileTimeSpec), followSymlink: Bool) throws(LowLevelError) {
        let platformTimes = (times.0.platformFileTime, times.1.platformFileTime)
        try execThrowingCFunction {
            withUnsafePointer(to: platformTimes) { ptr in
                ptr.withMemoryRebound(to: timespec.self, capacity: 2) { reboundPtr in
                    path.withPlatformString { pathPtr in
                        utimensat(AT_FDCWD, pathPtr, reboundPtr, followSymlink ? 0 : AT_SYMLINK_NOFOLLOW)
                    }
                }
            }
        }
    }
    #endif
    

    package static func setFileTimes(
        forItemAt path: FilePath, 
        access: FileTimeSpec?, 
        modification: FileTimeSpec?,
        creation: FileTimeSpec? = nil,
        followSymlink: Bool
    ) throws(LowLevelError) {

        if access == nil && modification == nil && creation == nil { return }

        #if canImport(WinSDK)

        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .writeOnly(metadataOnly: true), noFollow: !followSymlink, platformSpecificOptions: .windows.backupSemantics)
        )
        try handle.setFileTimes(access: access, modification: modification, creation: creation)
        try handle.close()

        #elseif canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

        // MARK: TODO: on Darwin, use setattrlist to set the three times in one syscall

        let access = access ?? .utimeOmit

        var times = (access, FileTimeSpec(platformFileTime: .init()))

        if let creation {
            times.1 = creation
            try self.utimens(for: path, times: times, followSymlink: followSymlink)
        }

        guard creation == nil || modification != nil else {
            // the next call is only necessary when creation time is not set or modification time need to be set
            return
        }

        times.1 = modification ?? .utimeOmit

        try self.utimens(for: path, times: times, followSymlink: followSymlink)

        #else 

        var times = (access ?? .utimeOmit, modification ?? .utimeOmit)

        try self.utimens(for: path, times: times, followSymlink: followSymlink)

        #endif 

    }


    package static func getFileTimes(
        fromItemAt path: FilePath,
        followSymlink: Bool
    ) throws(LowLevelError) -> FileTimes {

        #if canImport(WinSDK)

        if followSymlink == false, let getFileInformationByNamePtr = getGetFileInformationByNameFuncPtr() {

            var fileInfo = FILE_STAT_INFORMATION()

            try execThrowingCFunction {
                path.withPlatformString { pathPtr in 
                    getFileInformationByNamePtr(pathPtr, FileStatByNameInfo, &fileInfo, DWORD(MemoryLayout<FILE_STAT_INFORMATION>.size)).boolValue
                }
            }

            return .init(
                lastAccess: .init(largeInteger: fileInfo.LastAccessTime), 
                lastModification: .init(largeInteger: fileInfo.LastWriteTime), 
                lastChange: .init(largeInteger: fileInfo.ChangeTime),
                creation: .init(largeInteger: fileInfo.CreationTime)
            )

        }

        let handle = try UnsafeSystemHandle.open(
            at: path, 
            openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: !followSymlink)
        )
        
        let times = try handle.fileTimes()

        try handle.close()

        return times

        #else

        let st = if followSymlink {
            try ustat(path)
        } else {
            try ulstat(path)
        }
        return .init(
            lastAccess: st.st_atim, 
            lastModification: st.st_mtim, 
            lastChange: st.st_ctim,
            creation: st.st_btim
        )

        #endif 

    }

}



// MARK: - Attributes & Flags
extension InternalFS {

    package static func getFileAttributes(forItemAt path: FilePath, followSymlink: Bool) throws(LowLevelError) -> PlatformFileAttributes {
        #if canImport(WinSDK)
        if followSymlink {
            let handle = try UnsafeSystemHandle.open(
                at: path,
                openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: false, platformSpecificOptions: .windows.backupSemantics)
            )
            let attr = try handle.fileAttributes()
            try handle.close()
            return attr
        }
        let attribubtes = path.withPlatformString { pathPtr in
            GetFileAttributesW(pathPtr)
        }
        guard attribubtes != DWORD(INVALID_FILE_ATTRIBUTES) else {
            try LowLevelError.assertError()
        }
        return .init(rawValue: attribubtes)
        #else
        .init(rawValue: try followSymlink ? ustat(path).st_flags : ulstat(path).st_flags)
        #endif
    }

    #if canImport(WinSDK) || canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

    package static func setFileAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes, followSymlink: Bool) throws(LowLevelError) {

        #if canImport(WinSDK)
        
        if followSymlink {
            let handle = try UnsafeSystemHandle.open(
                at: path,
                openOptions: .init(access: .readWrite(metadataOnly: true), noFollow: false, platformSpecificOptions: .windows.backupSemantics)
            )
            try handle.setFileAttributes(attributes)
            try handle.close()
            return
        }

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                SetFileAttributesW(pathPtr, attributes.normalized.rawValue)
            }
        }

        #else

        try execThrowingCFunction {
            path.withPlatformString { pathPtr in 
                followSymlink ? chflags(pathPtr, attributes.rawValue) : lchflags(pathPtr, attributes.rawValue)
            }
        }

        #endif 

    }

    #elseif canImport(Glibc) || canImport(Musl)

    @available(*, unavailable, message: "Setting the statx attributes is not supported on Linux / Android, please use inode flags instead")
    package static func setFileAttributes(forItemAt path: FilePath, attributes: PlatformFileAttributes, followSymlink: Bool) throws(LowLevelError) {
        throw .init(kind: .unsupported)
    }


    package static func setFileInodeFlags(forItemAt path: FilePath, flags: LinuxInodeFlags, followSymlink: Bool) throws(LowLevelError) {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: !followSymlink))
        try fd.setFileInodeFlags(flags)
        try fd.close()
    }


    package static func readFileInodeFlags(forItemAt path: FilePath, followSymlink: Bool) throws(LowLevelError) -> LinuxInodeFlags {
        let fd = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .readOnly(), noFollow: !followSymlink))
        let flags = try fd.fileInodeFlags()
        try fd.close()
        return flags
    }


    package static func fileAttributesToInodeFlags(_ attributes: PlatformFileAttributes) -> LinuxInodeFlags {
        var inodeFlags = [] as LinuxInodeFlags
        if attributes.contains(.linux.isCompressed) { inodeFlags.insert(.compress) }
        if attributes.contains(.linux.isImmutable) { inodeFlags.insert(.immutable) }
        if attributes.contains(.linux.isAppendOnly) { inodeFlags.insert(.appendOnly) }
        if attributes.contains(.linux.noDump) { inodeFlags.insert(.noDump) }
        if attributes.contains(.linux.isEncrypted) { inodeFlags.insert(.encrypted) }
        if attributes.contains(.linux.isVerityProtected) { inodeFlags.insert(.verityProtected) }
        return inodeFlags
    }

    #endif 

}
