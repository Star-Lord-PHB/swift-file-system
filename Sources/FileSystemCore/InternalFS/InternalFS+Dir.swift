import PlatformCLib
import CFileSystem
import SystemPackage



extension InternalFS {

    #if !canImport(WinSDK)

    fileprivate static func fdopendir(for handle: consuming UnsafeSystemHandle) throws(LowLevelError) -> OpaquePointer {
        guard let dirStream = PlatformCLib.fdopendir(handle.take()) else {
            try LowLevelError.assertError()
        }
        return .init(UnsafeRawPointer(dirStream))
    }


    fileprivate static func readdir(from dirStream: OpaquePointer) throws(LowLevelError) -> dirent? {

        errno = 0

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        let dirStream = UnsafeMutablePointer<DIR>(dirStream)
        #endif 

        guard let dirEntryPtr = PlatformCLib.readdir(dirStream) else {
            try LowLevelError.check()
            return nil
        }

        return dirEntryPtr.move()  

    }


    fileprivate static func closedir(_ dirStream: OpaquePointer) throws(LowLevelError) {

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        let dirStream = UnsafeMutablePointer<DIR>(dirStream)
        #endif 

        try execThrowingCFunction {
            PlatformCLib.closedir(dirStream)
        }

    }

    package struct PosixDirectoryStream: ~Copyable {

        private var dirStream: OpaquePointer

        package init(unsafeSystemHandle: consuming UnsafeSystemHandle) throws(LowLevelError) {
            let rawStream = try fdopendir(for: unsafeSystemHandle)
            self.dirStream = .init(UnsafeRawPointer(rawStream))
        }

        deinit {
            try? closedir(dirStream)
        }

        package mutating func next() throws(LowLevelError) -> dirent? {
            return try readdir(from: dirStream)
        }

        package consuming func close() throws(LowLevelError) {
            let rawStream = self.dirStream
            discard self
            try closedir(rawStream)
        }

    }

    #endif

}



extension InternalFS {

    #if !canImport(WinSDK)

    package struct PosixFTSStream: ~Copyable {

        private var entryStream: UnsafeMutablePointer<FTS>
        
        private(set) var closed: Bool = false


        package init(path: FilePath, doStat: Bool = true, includeDots: Bool = true) throws(LowLevelError) {

            var ftsFlags = FTS_PHYSICAL | FTS_NOCHDIR | FTS_COMFOLLOW
            if includeDots {
                ftsFlags |= FTS_SEEDOT
            }
            if doStat == false {
                ftsFlags |= FTS_NOSTAT
            }

            let entryStream = path.withPlatformString { cStr in
                fts_open([UnsafeMutablePointer<CChar>(mutating: cStr), nil], ftsFlags, nil)
            }
            guard let entryStream else {
                try LowLevelError.assertError()
            }

            self.entryStream = entryStream

        }

        deinit {
            guard closed == false else { return }
            fts_close(entryStream)
        }

        package mutating func next() throws(LowLevelError) -> FTSENT? {

            errno = 0

            guard let entry = fts_read(entryStream) else {
                try LowLevelError.check()
                return nil
            }

            return entry.move()

        }

        package consuming func close() throws(LowLevelError) {
            try execThrowingCFunction {
                fts_close(self.entryStream)
            }
            closed = true
        }

    }

    #endif 

}



extension InternalFS {

    #if canImport(WinSDK)

    package struct WindowsFindHandle: ~Copyable {

        private var findHandle: WinSDK.HANDLE?
        package let rootPath: FilePath
        private(set) var closed: Bool = false

        package init(path: FilePath) {
            self.findHandle = nil
            self.rootPath = path
        }

        deinit {
            guard closed == false else { return }
            if let findHandle {
                FindClose(findHandle)
            }
        }

        package mutating func next() throws(LowLevelError) -> WIN32_FIND_DATAW? {

            SetLastError(DWORD(ERROR_SUCCESS))

            var findData = WIN32_FIND_DATAW()

            if let findHandle {

                guard FindNextFileW(findHandle, &findData) else {
                    let errorCode = GetLastError()
                    if errorCode == ERROR_NO_MORE_FILES {
                        return nil
                    } else {
                        throw .init(rawSystemCode: errorCode)!
                    }
                }

            } else {

                let openedHandle = rootPath.appending("*").withPlatformString { cStr in
                    FindFirstFileExW(cStr, FindExInfoBasic, &findData, FindExSearchNameMatch, nil, DWORD(FIND_FIRST_EX_LARGE_FETCH))
                }
                guard let openedHandle, openedHandle != INVALID_HANDLE_VALUE else {
                    try LowLevelError.assertError()
                }
                findHandle = openedHandle

            }

            return findData

        }

        package consuming func close() throws(LowLevelError) {

            SetLastError(DWORD(NO_ERROR))
            if let findHandle {
                try execThrowingCFunction {
                    FindClose(findHandle)
                }
            }

            closed = true

        }

    }



    package struct WindowsByHandleDirInfoStream: ~Copyable {

        let handle: UnsafeSystemHandle
        private let buffer: UnsafeOwnedMutableRawBufferPointer = .swiftAllocate(
            byteCount: 64 * 1024, 
            alignment: MemoryLayout<_FILE_ID_EXTD_DIR_INFO>.alignment
        )
        private var currentPtr: UnsafeRawPointer? = nil

        package init(unsafeSystemHandle: consuming UnsafeSystemHandle) {
            self.handle = unsafeSystemHandle
        }

        package consuming func close() throws(LowLevelError) {
            try handle.close()
        }

        package mutating func next() throws(LowLevelError) -> UnsafeUnownedPointer<_FILE_ID_EXTD_DIR_INFO>? {

            let nextOffset = currentPtr?.assumingMemoryBound(to: _FILE_ID_EXTD_DIR_INFO.self).pointee.NextEntryOffset

            if let nextOffset, nextOffset > 0 {

                currentPtr = currentPtr!.advanced(by: Int(nextOffset))

            } else {

                let infoClass = currentPtr == nil ? FileIdExtdDirectoryRestartInfo : FileIdExtdDirectoryInfo
                
                guard GetFileInformationByHandleEx(
                    handle.unsafeRawHandle, 
                    infoClass, 
                    buffer.baseAddress!.unsafeRawPtr, 
                    DWORD(buffer.byteCount)
                ) else {
                    let error = GetLastError()
                    if error == ERROR_NO_MORE_FILES {
                        return nil
                    }
                    throw LowLevelError(rawSystemCode: error)!
                }

                currentPtr = .init(buffer.baseAddress!.unsafeRawPtr)

            }

            if let currentPtr {
                return _overrideLifetime(
                    UnsafeUnownedPointer(unownedPointer: currentPtr.assumingMemoryBound(to: _FILE_ID_EXTD_DIR_INFO.self)),
                    borrowing: self
                )
            }

            return nil

        }

    }

    #endif 

}
