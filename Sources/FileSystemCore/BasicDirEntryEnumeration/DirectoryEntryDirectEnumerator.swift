import PlatformCLib
import SystemPackage 



package struct DirectoryEntryDirectEnumerator: ~Copyable {

    #if canImport(WinSDK)
    package typealias SystemEntryDataType = WIN32_FIND_DATAW
    private var findHandle: InternalFS.WindowsFindHandle?
    package let rootPath: FilePath
    #else
    package typealias SystemEntryDataType = dirent
    private var dirStream: InternalFS.PosixDirectoryStream?
    package let rootPath: FilePath
    #endif


    package private(set) var ended: Bool = false
    package let options: FileOperationOptions.DirectoryTraversalOption


    package init(
        unsafeSystemHandle: consuming UnsafeSystemHandle, 
        path: FilePath, 
        options: FileOperationOptions.DirectoryTraversalOption
    ) throws(LowLevelError) {

        self.options = options

        #if canImport(WinSDK)
        self.rootPath = path
        self.findHandle = .init(path: path)
        #else
        self.rootPath = path
        self.dirStream = try .init(unsafeSystemHandle: unsafeSystemHandle)
        #endif

    }


    #if canImport(WinSDK)
    package init(
        path: FilePath, 
        options: FileOperationOptions.DirectoryTraversalOption
    ) {
        self.options = options
        self.rootPath = path
        self.findHandle = .init(path: path)
    }
    #endif


    deinit {
        #if canImport(WinSDK)
        try? findHandle?.close()
        #else
        try? dirStream?.close()
        #endif
    }


    package mutating func next() throws(LowLevelError) -> DirectoryEntry? {
        
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


    private mutating func _next() throws(LowLevelError) -> DirectoryEntry? {
        #if canImport(WinSDK)
        while let entry = try findHandle?.next() {
            lazy var path = extractPath(from: entry)
            let type = extractType(from: entry)
            if options.contains(.skipDir) && type == .directory { continue }
            if !options.contains(.includeDotEntries) && path.lastComponent?.kind != .regular { continue }
            return .init(path: path, type: type)
        }
        return nil
        #else
        while let entry = try dirStream?.next() {
            lazy var path = extractPath(from: entry)
            let type = extractType(from: entry)
            if options.contains(.skipDir) && type == .directory { continue }
            if !options.contains(.includeDotEntries) && path.lastComponent?.kind != .regular { continue }
            return .init(path: path, type: type)
        }
        return nil
        #endif 
    }


    private func extractPath(from systemEntry: borrowing SystemEntryDataType) -> FilePath {
        
        #if canImport(WinSDK)
        return withUnsafePointer(to: systemEntry.cFileName) { ptr in 
            ptr.withMemoryRebound(to: WCHAR.self, capacity: Int(MAX_PATH)) { wcharPtr in
                FilePath(platformString: wcharPtr)
            }
        } 
        #else
        let nameLen = withUnsafeBytes(of: systemEntry.d_name) { $0.count }
        return withUnsafePointer(to: systemEntry.d_name) { originalPtr in 
            originalPtr.withMemoryRebound(to: CChar.self, capacity: nameLen) { pointer in
                FilePath(platformString: pointer)
            }
        }
        #endif

    }


    private func extractType(from systemEntry: borrowing SystemEntryDataType) -> FileKind {

        #if canImport(WinSDK)

        return FileKind(
            windowsFileAttributes: systemEntry.dwFileAttributes,
            reparseTag: systemEntry.dwReserved0
        )

        #else

        return switch systemEntry.d_type {
            case .init(DT_REG):     .regular
            case .init(DT_DIR):     .directory
            case .init(DT_LNK):     .symlink
            case .init(DT_SOCK):    .socket
            case .init(DT_BLK):     .block
            case .init(DT_CHR):     .character
            case .init(DT_FIFO):    .fifo
            default:                .unknown
        } as FileKind
        
        #endif

    }


    private mutating func _clean() throws(LowLevelError) {

        guard !ended else { return }

        #if canImport(WinSDK)
        
        try findHandle.take()?.close()

        #else

        try dirStream.take()?.close()

        #endif

    }


    private mutating func endEnumeration() throws(LowLevelError) {
        defer {
            ended = true
        }
        try _clean()
    }

}
