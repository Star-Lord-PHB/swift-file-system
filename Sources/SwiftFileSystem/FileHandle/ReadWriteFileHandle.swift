import struct SystemPackage.FilePath
import FileSystemCore



public struct ReadWriteFileHandle
: ~Copyable, @unchecked Sendable
, PositionalReadFileHandleProtocol
, PositionalWriteFileHandleProtocol, PersistentFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let path: FilePath


    init(unsafeHandleContext: consuming UnsafeHandleContext, path: FilePath) {
        self.context = unsafeHandleContext
        self.path = path
    }

}



extension ReadWriteFileHandle {

    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: FilePermissions? = nil
    ) throws(PlatformError) {

        #if canImport(WinSDK)

        try self.init(path: path, options: options, creationPermissions: .init(creationPermissions))

        #else

        let openOptions = UnsafeSystemHandle.OpenOptions(
            access: .readWrite,
            creation: options.createFile.mappedSystemCreationOption,
            truncate: options.truncate,
            closeOnExec: options.closeOnExec,
            platformOpenFlagsDiff: .inserted(options.noFollow ? .posix.noFollow : [])
        )

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.open(
                at: path, 
                openOptions: openOptions, 
                creationPermissions: creationPermissions
            )
        }

        self.init(unsafeHandleContext: .init(handle: handle, openOptions: openOptions), path: path)

        #endif

    }


    #if canImport(WinSDK)
    public init(
        forFileAt path: FilePath, 
        options: FileOperationOptions.OpenForWriting = .editFile(), 
        creationPermissions: WindowsSecurityDescriptorView
    ) throws(PlatformError) {
        try self.init(path: path, options: options, creationPermissions: .securityDescriptor(creationPermissions))
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

    private init(
        path: FilePath,
        options: FileOperationOptions.OpenForWriting,
        creationPermissions: WindowsCreationPermissions
    ) throws(PlatformError) {

        let creationOption = options.createFile.mappedSystemCreationOption

        var openOptions = UnsafeSystemHandle.OpenOptions(
            access: .readWrite, 
            creation: creationOption,
            truncate: options.truncate, 
            noFollow: options.noFollow, 
            closeOnExec: options.closeOnExec
        )

        if options.noFollow && options.truncate && creationOption != .assertMissing {
            openOptions.truncate = false
        }

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            return switch creationPermissions {
                case .inheritFromParent:
                    try UnsafeSystemHandle.open(at: path, openOptions: openOptions)
                case .posix(let permissions):
                    try UnsafeSystemHandle.open(at: path, openOptions: openOptions, creationPermissions: permissions)
                case .securityDescriptor(let descriptor):
                    try UnsafeSystemHandle.open(at: path, openOptions: openOptions, creationPermissions: descriptor)
            }
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

        self.init(
            unsafeHandleContext: .init(handle: handle, openOptions: openOptions),
            path: path,
        )

    }
    #endif


    package consuming func takeUnsafeHandleContext() -> UnsafeHandleContext {
        self.context
    }


    public consuming func close() throws(PlatformError) {
        do {
            try context.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public var unsafeHandleContext: UnsafeHandleContextView {
        @_lifetime(borrow self) get { context.view }
    }


    @_lifetime(borrow self)
    public func sequentialAccessor() -> SequentialAccessor {
        .init(readWriteHandle: self)
    }

}




extension ReadWriteFileHandle {

    public struct SequentialAccessor
    : ~Escapable
    , MutatingSequentialReadFileHandleProtocol
    , MutatingSequentialWriteFileHandleProtocol, MutatingSeekableFileHandleProtocol
    , ResizableFileHandleProtocol, PersistentFileHandleProtocol
    , SystemHandleSupportedFileHandleProtocol {

        private var accessor: PositionalHandleAccessor

        public var path: FilePath { accessor.path }
        public var currentOffset: Int64 { accessor.currentOffset }


        @_lifetime(borrow readWriteHandle)
        init(readWriteHandle: borrowing ReadWriteFileHandle) {
            self.accessor = .init(unsafeHandleContext: readWriteHandle.context, path: readWriteHandle.path)
        }


        public var unsafeHandleContext: UnsafeHandleContextView {
            @_lifetime(copy self) get { accessor.unsafeHandleContext }
        }


        @discardableResult
        @_lifetime(self: copy self)
        public mutating func seek(to offset: Int64, relativeTo whence: FileOperationOptions.SeekWhence = .beginning) throws(PlatformError) -> Int64 {
            try accessor.seek(to: offset, relativeTo: whence)
        }


        @_lifetime(self: copy self)
        @_lifetime(buffer: copy buffer)
        public mutating func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64 {
            try accessor.read(into: &buffer)
        }


        @discardableResult
        @_lifetime(self: copy self)
        public mutating func write(_ buffer: RawSpan) throws(PlatformError) -> Int64 {
            try accessor.write(buffer)
        }

    }

}
