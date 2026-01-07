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
    let rootPath: FilePath
    #else
    typealias SystemEntryDataType = dirent
    private var dirStream: InternalFS.PosixDirectoryStream?
    let rootPath: FilePath
    #endif


    private(set) var ended: Bool = false


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) throws(SystemError) {

        #if canImport(WinSDK)

        self.rootPath = path
        self.findHandle = try .init(path: path)

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
        #if canImport(WinSDK)
        return try findHandle?.next().flatMap { extractEntryInfo(from: $0) }
        #else
        return try dirStream?.next().flatMap { extractEntryInfo(from: $0) }
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
            } as FileType

            return DirectoryEntry(path: .init(name), type: type).map { .entry($0) }

        #else

            let nameLen = withUnsafeBytes(of: systemEntry.d_name) { $0.count }

            let name = withUnsafePointer(to: systemEntry.d_name) { originalPtr in 
                originalPtr.withMemoryRebound(to: CChar.self, capacity: nameLen) { pointer in
                    String(cString: pointer)
                }
            }

            let type = switch systemEntry.d_type {
                case .init(DT_REG):     .regular
                case .init(DT_DIR):     .directory
                case .init(DT_LNK):     .symlink
                case .init(DT_SOCK):    .socket
                case .init(DT_BLK):     .block
                case .init(DT_CHR):     .character
                case .init(DT_FIFO):    .fifo
                default:                .unknown
            } as FileType

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