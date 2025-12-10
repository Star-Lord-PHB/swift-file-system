import PlatformCLib
import SystemPackage 



struct DirectoryEntryDirectEnumerator: ~Copyable {

    enum Element {
        case entry(DirectoryEntry)
        case entryError(FilePath, SystemError)

        var path: FilePath {
            switch self {
                case .entry(let entry):         entry.path
                case .entryError(let path, _):  path
            }
        }
    }

    #if canImport(WinSDK)
    typealias SystemEntryDataType = WIN32_FIND_DATAW
    private var findHandle: WinSDK.HANDLE?
    #else
    typealias SystemEntryDataType = UnsafeMutablePointer<dirent>
    private var dirStream: OpaquePointer
    #endif

    let rootPath: FilePath

    private(set) var ended: Bool = false


    init(unsafeSystemHandle: borrowing UnsafeSystemHandle, path: FilePath) throws(SystemError) {
        try self.init(unsafeUnownedSystemHandle: unsafeSystemHandle.unownedHandle(), path: path)
    }


    init(unsafeUnownedSystemHandle handle: UnsafeUnownedSystemHandle, path: FilePath) throws(SystemError) {
        #if canImport(WinSDK)
        try self.init(unsafeRawHandle: handle.unsafeRawHandle, path: path)
        #else
        let duplicatedFd = dup(handle.unsafeRawHandle)
        guard duplicatedFd >= 0 else {
            try SystemError.assertError()
        }
        try self.init(unsafeRawHandle: duplicatedFd, path: path)
        #endif 
    }


    private init(unsafeRawHandle: UnsafeSystemHandle.SystemHandleType, path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        // The find handle will not be initialized here, and will only be initialized on the first call to next()
        // This is because on Windows, we need to use FindFirstFileExW to open the handle, which will give us the first result directly.
        self.findHandle = nil

        #else

        guard let dirStream = fdopendir(unsafeRawHandle) else {
            try SystemError.assertError()
        }

        self.dirStream = .init(UnsafeRawPointer(dirStream))

        #endif

        self.rootPath = path

    }


    deinit {
        try? _clean()
    }


    mutating func next() throws(SystemError) -> Element? {
        
        guard !ended else { return nil }
    
        do {
            if let entry = try _next() {
                return entry
            } else {
                try endEnumeration()
                return nil
            }
        } catch {
            try? endEnumeration()
            throw error
        }

    }


    mutating func _next() throws(SystemError) -> Element? {

        #if canImport(WinSDK)

        var findData = WIN32_FIND_DATAW()

        if let findHandle {

            guard FindNextFileW(findHandle, &findData) else {
                let errorCode = GetLastError()
                if errorCode == ERROR_NO_MORE_FILES {
                    return nil
                } else {
                    throw SystemError(code: errorCode)
                }
            }

        } else {

            findHandle = rootPath.appending("*").string.withCString(encodedAs: UTF16.self) { cStr in 
                FindFirstFileExW(cStr, FindExInfoBasic, &findData, FindExSearchNameMatch, nil, DWORD(FIND_FIRST_EX_LARGE_FETCH))
            }
            guard let findHandle, findHandle != INVALID_HANDLE_VALUE else {
                try SystemError.assertError()
            }

        }

        return extractEntryInfo(from: findData)

        #else

        errno = 0

        guard let dirEntryPtr = readdir(.init(dirStream)) else {
            try SystemError.check()
            return nil
        }

        return extractEntryInfo(from: dirEntryPtr)

        #endif 

    }


    private func extractEntryInfo(from systemEntry: borrowing SystemEntryDataType) -> Element? {

        #if canImport(WinSDK)

            let fileAttributes = systemEntry.dwFileAttributes

            let name = withUnsafePointer(to: systemEntry.cFileName) { ptr in 
                ptr.withMemoryRebound(to: WCHAR.self, capacity: Int(MAX_PATH)) { wcharPtr in
                    String(decodingCString: wcharPtr, as: UTF16.self)
                }
            }

            let hasReparseTagSymlink = (systemEntry.dwReserved0 == IO_REPARSE_TAG_SYMLINK)

            let type = if fileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0 {
                .directory
            } else if fileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 && hasReparseTagSymlink {
                .symlink
            } else if fileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
                .unknown
            } else {
                .regular
            } as FileInfo.FileType

            return DirectoryEntry(path: .init(name), type: type).map { .entry($0) }

        #else

            let nameLen = withUnsafeBytes(of: &systemEntry.pointee.d_name) { $0.count }

            let name = systemEntry.pointer(to: \.d_name)!.withMemoryRebound(to: CChar.self, capacity: nameLen) { pointer in
                String(cString: pointer)
            }

            let type = FileInfo.FileType(d_type: systemEntry.pointee.d_type)

            return DirectoryEntry(path: .init(name), type: type).map { .entry($0) }

        #endif

    }


    private func _clean() throws(SystemError) {

        guard !ended else { return }

        #if canImport(WinSDK)
        
        SetLastError(DWORD(NO_ERROR))
        if let findHandle {
            try execThrowingCFunction {
                FindClose(findHandle)
            }
        }

        #else

        try execThrowingCFunction {
            closedir(.init(dirStream))
        }

        #endif

    }


    private mutating func endEnumeration() throws(SystemError) {
        defer {
            ended = true
        }
        try _clean()
    }

}



extension OpaquePointer {
    fileprivate init(_ ptr: OpaquePointer) {
        self = ptr
    }
}