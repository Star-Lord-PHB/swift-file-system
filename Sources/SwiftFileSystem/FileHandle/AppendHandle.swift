import struct SystemPackage.FilePath
import FileSystemCore



/// A file handle for appending data to the end of a file atomically.
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

    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - creationPermissions: The permissions to use when creating the file, 
    ///                          or `nil` for default permissions, ignored if creation is not required.
    /// 
    /// The default permissions being used when `creationPermissions` is not specified are `0o644` for Posix
    /// and inheriting from parent directory for Windows.
    /// 
    /// - Attention: Windows does not support Posix style permissions directly, so this API will try to map
    ///              the Posix permissions to Windows DACL with best effort. If more fine-grained control is 
    ///              required, use the overloads that accept Windows security descriptors.
    /// 
    /// - Seealso: ``FileOperationOptions.OpenForWriting``
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
            creation: options.createFile,
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
    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - creationPermissions: The security descriptor specifying the permissions to use when creating the 
    ///                          file, ignored if creation is not required.
    /// 
    /// - Seealso: ``FileOperationOptions.OpenForWriting``
    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: WindowsSecurityDescriptorView
    ) throws(PlatformError) {
        try self.init(path: path, options: options, creationPermissions: .securityDescriptor(creationPermissions))
    }


    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - creationPermissions: The security descriptor specifying the permissions to use when creating the 
    ///                          file, ignored if creation is not required.
    /// 
    /// - Seealso: ``FileOperationOptions.OpenForWriting``
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


    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    ///   - creationPermissions: The security descriptor specifying the permissions to use when creating the 
    ///                          file, ignored if creation is not required.
    /// 
    /// - Seealso: ``FileOperationOptions.OpenForWriting``
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

        let creationOption = options.createFile
        
        var openOptions = UnsafeSystemHandle.OpenOptions(
            access: .writeOnly, 
            creation: creationOption,
            truncate: options.truncate, 
            append: true,
            followSymlink: !options.noFollow, 
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


    /// Closes the file handle, releases resources and ends the lifetime.
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
    public func append(_ bytes: RawSpan) throws(PlatformError) -> Int64 {

        try bytes.withUnsafeBytes { buffer throws(PlatformError) in
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
