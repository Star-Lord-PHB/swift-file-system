import PlatformCLib
import CFileSystem
import SystemPackage



extension InternalFS {

    #if !canImport(WinSDK)

    fileprivate static func fdopendir(for handle: consuming UnsafeSystemHandle) throws(SystemError) -> OpaquePointer {
        guard let dirStream = PlatformCLib.fdopendir(handle.take()) else {
            try SystemError.assertError()
        }
        return .init(UnsafeRawPointer(dirStream))
    }


    fileprivate static func readdir(from dirStream: OpaquePointer) throws(SystemError) -> dirent? {

        errno = 0

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        let dirStream = UnsafeMutablePointer<DIR>(dirStream)
        #endif 

        guard let dirEntryPtr = PlatformCLib.readdir(dirStream) else {
            try SystemError.check()
            return nil
        }

        return dirEntryPtr.move()  

    }


    fileprivate static func closedir(_ dirStream: OpaquePointer) throws(SystemError) {

        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        let dirStream = UnsafeMutablePointer<DIR>(dirStream)
        #endif 

        try execThrowingCFunction {
            PlatformCLib.closedir(dirStream)
        }

    }

    package struct PosixDirectoryStream: ~Copyable {

        private var dirStream: OpaquePointer

        package init(unsafeSystemHandle: consuming UnsafeSystemHandle) throws(SystemError) {
            let rawStream = try fdopendir(for: unsafeSystemHandle)
            self.dirStream = .init(UnsafeRawPointer(rawStream))
        }

        deinit {
            try? closedir(dirStream)
        }

        package mutating func next() throws(SystemError) -> dirent? {
            return try readdir(from: dirStream)
        }

        package consuming func close() throws(SystemError) {
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


        package init(path: FilePath, doStat: Bool = true) throws(SystemError) {

            var ftsFlags = FTS_PHYSICAL | FTS_NOCHDIR | FTS_SEEDOT | FTS_COMFOLLOW
            if doStat == false {
                ftsFlags |= FTS_NOSTAT
            }

            let entryStream = path.withPlatformString { cStr in
                fts_open([UnsafeMutablePointer<CChar>(mutating: cStr), nil], ftsFlags, nil)
            }
            guard let entryStream else {
                try SystemError.assertError()
            }

            self.entryStream = entryStream

        }

        deinit {
            guard closed == false else { return }
            fts_close(entryStream)
        }

        package mutating func next() throws(SystemError) -> FTSENT? {

            errno = 0

            guard let entry = fts_read(entryStream) else {
                try SystemError.check()
                return nil
            }

            return entry.move()

        }

        package consuming func close() throws(SystemError) {
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

        package init(path: FilePath) throws(SystemError) {
            self.findHandle = nil
            self.rootPath = path
        }

        deinit {
            guard closed == false else { return }
            if let findHandle {
                FindClose(findHandle)
            }
        }

        package mutating func next() throws(SystemError) -> WIN32_FIND_DATAW? {

            SetLastError(DWORD(ERROR_SUCCESS))

            var findData = WIN32_FIND_DATAW()

            if let findHandle {

                guard FindNextFileW(findHandle, &findData) else {
                    let errorCode = GetLastError()
                    if errorCode == ERROR_NO_MORE_FILES {
                        return nil
                    } else {
                        throw SystemError(code: errorCode)!
                    }
                }

            } else {

                findHandle = rootPath.appending("*").withPlatformString { cStr in 
                    FindFirstFileExW(cStr, FindExInfoBasic, &findData, FindExSearchNameMatch, nil, DWORD(FIND_FIRST_EX_LARGE_FETCH))
                }
                guard let findHandle, findHandle != INVALID_HANDLE_VALUE else {
                    try SystemError.assertError()
                }

            }

            return findData

        }

        package consuming func close() throws(SystemError) {

            SetLastError(DWORD(NO_ERROR))
            if let findHandle {
                try execThrowingCFunction {
                    FindClose(findHandle)
                }
            }

            closed = true

        }

    }

    #endif 

}