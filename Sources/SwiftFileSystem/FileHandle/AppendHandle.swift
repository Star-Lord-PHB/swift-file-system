import struct SystemPackage.FilePath
import FileSystemCore



public struct AppendHandle
: ~Copyable, @unchecked Sendable
, AppendableFileHandleProtocol, PersistentFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let path: FilePath


    init(unsafeHandleContext: consuming UnsafeHandleContext, path: FilePath) {
        self.context = unsafeHandleContext
        self.path = path
    }

}



extension AppendHandle {

    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: FilePermissions? = nil
    ) throws(PlatformError) {

        #if canImport(WinSDK)

        try self.init(path: path, options: options, creationPermissions: .init(creationPermissions))

        #else
        
        let openOptions = UnsafeSystemHandle.OpenOptions(
            access: .writeOnly, 
            creation: options.createFile.mappedSystemCreationOption,
            truncate: options.truncate, 
            append: true,
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
        try self.init(
            forFileAt: path,
            options: options,
            creationPermissions: creationPermissions.view
        )
    }


    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(PlatformError) {
        try self.init(
            forFileAt: path,
            options: options,
            creationPermissions: creationPermissions.view
        )
    }


    private init(
        path: FilePath,
        options: FileOperationOptions.OpenForWriting,
        creationPermissions: WindowsCreationPermissions
    ) throws(PlatformError) {

        let creationOption = options.createFile.mappedSystemCreationOption
        
        var openOptions = UnsafeSystemHandle.OpenOptions(
            access: .writeOnly, 
            creation: creationOption,
            truncate: options.truncate, 
            append: true,
            noFollow: options.noFollow, 
            closeOnExec: options.closeOnExec
        )

        if options.noFollow && options.truncate && creationOption != .assertMissing {
            openOptions.windowsExtraAccess.insert(.genericWrite)
            openOptions.truncate = false
        }

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            switch creationPermissions {
                case .inheritFromParent:
                    try UnsafeSystemHandle.open(at: path, openOptions: openOptions)
                case .posix(let permissions):
                    try UnsafeSystemHandle.open(at: path, openOptions: openOptions, creationPermissions: permissions)
                case .securityDescriptor(let sd):
                    try UnsafeSystemHandle.open(at: path, openOptions: openOptions, creationPermissions: sd)
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
            path: path
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

}



extension AppendHandle {

    @discardableResult
    public func append(_ buffer: RawSpan) throws(PlatformError) -> Int64 {

        try buffer.withUnsafeBytes { buffer throws(PlatformError) in
            try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
                #if canImport(WinSDK)
                try context.systemHandle.pwrite(contentsOf: buffer, to: -1)
                #else
                try context.systemHandle.write(contentsOf: buffer)
                #endif
            }
        }

    }

}
