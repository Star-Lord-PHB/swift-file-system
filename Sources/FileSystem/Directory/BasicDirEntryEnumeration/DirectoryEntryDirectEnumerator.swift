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
    private var findHandle: InternalFS.WindowsFindHandle?
    var rootPath: FilePath { findHandle.rootPath }
    #else
    typealias SystemEntryDataType = dirent
    private var dirStream: InternalFS.PosixDirectoryStream?
    let rootPath: FilePath
    #endif


    private(set) var ended: Bool = false


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        // The find handle will not be initialized here, and will only be initialized on the first call to next()
        // This is because on Windows, we need to use FindFirstFileExW to open the handle, which will give us the first result directly.
        self.findHandle = .init(path: path)

        #else

        self.rootPath = path
        self.dirStream = try .init(unsafeSystemHandle: unsafeSystemHandle)

        #endif
    }


    deinit {
        #if canImport(WinSDK)
        try? findHandle?.close()
        #else
        try? dirStream?.close()
        #endif
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
        return try dirStream?.next().flatMap { extractEntryInfo(from: $0) }
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

            let nameLen = withUnsafeBytes(of: systemEntry.d_name) { $0.count }

            let name = withUnsafePointer(to: systemEntry.d_name) { originalPtr in 
                originalPtr.withMemoryRebound(to: CChar.self, capacity: nameLen) { pointer in
                    String(cString: pointer)
                }
            }

            let type = FileInfo.FileType(d_type: systemEntry.d_type)

            return DirectoryEntry(path: .init(name), type: type).map { .entry($0) }

        #endif

    }


    private mutating func _clean() throws(SystemError) {

        guard !ended else { return }

        #if canImport(WinSDK)
        
        try findHandle.take()?.close()

        #else

        try dirStream.take()?.close()

        #endif

    }


    private mutating func endEnumeration() throws(SystemError) {
        defer {
            ended = true
        }
        try _clean()
    }

}