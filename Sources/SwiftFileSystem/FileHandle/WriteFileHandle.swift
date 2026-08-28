import struct SystemPackage.FilePath
import FileSystemCore



public struct WriteFileHandle
: ~Copyable, @unchecked Sendable
, PositionalWriteFileHandleProtocol, PersistentFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle 
    public let path: FilePath


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension WriteFileHandle {

    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: FilePermissions? = nil
    ) throws(PlatformError) {

        let creationOption = switch options.createFile {
            case .never:            .never
            case .createIfMissing:  .createIfMissing
            case .assertMissing:    .assertMissing
        } as UnsafeSystemHandle.OpenOptions.CreationOptions

        var openOptions = UnsafeSystemHandle.OpenOptions(
            access: .writeOnly(),
            creation: creationOption,
            truncate: options.truncate,
            noFollow: options.noFollow,
            closeOnExec: options.closeOnExec
        )

        #if canImport(WinSDK)
        if options.noFollow && options.truncate && creationOption != .assertMissing {
            openOptions.truncate = false
        }
        #endif

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.open(
                at: path, 
                openOptions: openOptions, 
                creationPermissions: creationPermissions
            )
        } kindConversion: { error in 
            switch error.systemCode {
                #if canImport(WinSDK)
                case .accessDenied: .windows.permissionDeniedOrIsADirectory
                #endif
                default: error.kind
            }
        }

        #if canImport(WinSDK) || canImport(Darwin)
        let type = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try handle.type()
        }
        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            switch type {
                case .symlink: throw .init(kind: .pathResolutionFailed)
                case .directory: throw .init(kind: .isADirectory)
                default: break
            }
        }
        #endif

        #if canImport(WinSDK)
        if options.noFollow && options.truncate && creationOption != .assertMissing && type == .regular {
            try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
                try handle.truncate()
            }
        }
        #endif

        self.init(unsafeSystemHandle: handle, path: path)

    }


    #if canImport(WinSDK)
    public init(
        forFileAt path: FilePath, 
        options: FileOperationOptions.OpenForWriting = .editFile(), 
        creationPermissions: WindowsSecurityDescriptorView
    ) throws(PlatformError) {

        let creationOption = switch options.createFile {
            case .never:            .never
            case .createIfMissing:  .createIfMissing
            case .assertMissing:    .assertMissing
        } as UnsafeSystemHandle.OpenOptions.CreationOptions
        
        var openOptions = UnsafeSystemHandle.OpenOptions(
            access: .writeOnly(), 
            creation: creationOption,
            truncate: options.truncate, 
            noFollow: options.noFollow, 
            closeOnExec: options.closeOnExec
        )

        if options.noFollow && options.truncate && creationOption != .assertMissing {
            openOptions.truncate = false
        }

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.open(
                at: path, 
                openOptions: openOptions, 
                creationPermissions: creationPermissions
            )
        } kindConversion: { error in 
            switch error.systemCode {
                case .accessDenied: .windows.permissionDeniedOrIsADirectory
                default: error.kind
            }
        }

        let type = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try handle.type()
        }
        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            switch type {
                case .symlink: throw .init(kind: .pathResolutionFailed)
                case .directory: throw .init(kind: .isADirectory)
                default: break
            }
        }

        if options.noFollow && options.truncate && creationOption != .assertMissing && type == .regular {
            try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
                try handle.truncate()
            }
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }

    public init(
        forFileAt path: FilePath, 
        options: FileOperationOptions.OpenForWriting = .editFile(), 
        creationPermissions: borrowing WindowsAbsoluteSecurityDescriptor
    ) throws(PlatformError) {
        try self.init(forFileAt: path, options: options, creationPermissions: creationPermissions.view)
    }

    public init(
        forFileAt path: FilePath, 
        options: FileOperationOptions.OpenForWriting = .editFile(), 
        creationPermissions: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) {
        try self.init(forFileAt: path, options: options, creationPermissions: creationPermissions.view)
    }
    #endif


    public consuming func close() throws(PlatformError) {
        do {
            try handle.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }


    @_lifetime(borrow self)
    public func sequentialWriter() -> SequentialWriter {
        .init(writeHandle: self)
    }

}



extension WriteFileHandle {

    public struct SequentialWriter
    : ~Escapable
    , MutatingSequentialWriteFileHandleProtocol, MutatingSeekableFileHandleProtocol
    , ResizableFileHandleProtocol, PersistentFileHandleProtocol
    , SystemHandleSupportedFileHandleProtocol {

        let handle: UnsafeUnownedSystemHandle
        public let path: FilePath

        public private(set) var currentOffset: Int64 = 0


        @_lifetime(borrow writeHandle)
        init(writeHandle: borrowing WriteFileHandle) {
            self.handle = writeHandle.handle.unownedHandle()
            self.path = writeHandle.path
        }


        public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
            try self.handle.unsafeTemporaryConvertingToOwning { handle throws(E) in
                try body(handle)
            }
        }


        @discardableResult
        @_lifetime(self: copy self)
        public mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) throws(PlatformError) -> Int64 {
            let newOffset = switch whence {
            case .current:
                try trySeek(from: self.currentOffset, by: offset, operation: .seekHandle(originalPath: path))
            case .beginning:
                try trySeek(from: 0, by: offset, operation: .seekHandle(originalPath: path))
            case .end:
                try trySeek(from: .init(fileInfo().size), by: offset, operation: .seekHandle(originalPath: path))
            }
            self.currentOffset = newOffset
            return newOffset
        }


        @discardableResult
        @_lifetime(self: copy self)
        public mutating func write(_ buffer: RawSpan) throws(PlatformError) -> Int64 {
            try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
                try self.handle.unsafeTemporaryConvertingToOwning { handle throws(LowLevelError) in
                    let currentOffset = self.currentOffset
                    let bytesWritten = try handle.pwrite(contentsOf: buffer, to: currentOffset)
                    self.currentOffset = currentOffset + bytesWritten
                    return bytesWritten
                }
            }
        }

    }

}
