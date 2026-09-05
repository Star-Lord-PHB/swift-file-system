import PlatformCLib
import SystemPackage 



package struct DirectoryEntryDirectEnumerator: ~Copyable {

    #if canImport(WinSDK)
    package typealias SystemEntryDataType = UnsafeUnownedPointer<_FILE_ID_EXTD_DIR_INFO>
    private var dirStream: InternalFS.WindowsByHandleDirInfoStream?
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
        self.dirStream = .init(unsafeSystemHandle: unsafeSystemHandle)
        #else
        self.rootPath = path
        self.dirStream = try .init(unsafeSystemHandle: unsafeSystemHandle)
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
        let skipDir = options.contains(.skipDir)
        let includeDotEntries = options.contains(.includeDotEntries)
        while let entry = try dirStream?.next() {
            lazy var path = Self.extractPath(from: entry)
            let type = Self.extractType(from: entry)
            if skipDir && type == .directory { continue }
            if !includeDotEntries && path.lastComponent?.kind != .regular { continue }
            return .init(path: path, type: type)
        }
        return nil
        #else
        while let entry = try dirStream?.next() {
            lazy var path = Self.extractPath(from: entry)
            let type = Self.extractType(from: entry)
            if options.contains(.skipDir) && type == .directory { continue }
            if !options.contains(.includeDotEntries) && path.lastComponent?.kind != .regular { continue }
            return .init(path: path, type: type)
        }
        return nil
        #endif 
    }


    private static func extractPath(from systemEntry: borrowing SystemEntryDataType) -> FilePath {
        
        #if canImport(WinSDK)
        let nameLength = Int(systemEntry.pointee.FileNameLength) / MemoryLayout<WCHAR>.size
        return systemEntry.pointer(to: \.FileName).unsafeRawPtr
            .withMemoryRebound(to: WCHAR.self, capacity: nameLength) { wcharPtr in
                var charArray = [WCHAR](UnsafeBufferPointer<WCHAR>(start: wcharPtr, count: nameLength))
                charArray.append(0) // Null-terminate the string
                return FilePath(platformString: charArray)
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


    private static func extractType(from systemEntry: borrowing SystemEntryDataType) -> FileKind {

        #if canImport(WinSDK)

        return FileKind(
            windowsFileAttributes: systemEntry.pointee.FileAttributes,
            reparseTag: systemEntry.pointee.ReparsePointTag
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
        
        try dirStream.take()?.close()

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
