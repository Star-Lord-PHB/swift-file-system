import struct SystemPackage.FilePath
import FileSystemCore



public struct AppendHandle
: ~Copyable, @unchecked Sendable
, AppendableFileHandleProtocol, PersistentFileHandleProtocol
, SystemHandleSupportedFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle
    public let path: FilePath


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension AppendHandle {

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
            append: true,
            noFollow: options.noFollow, 
            closeOnExec: options.closeOnExec,
            noBlocking: false
        )

        #if canImport(WinSDK)
        if options.noFollow && options.truncate && creationOption != .assertMissing {
            openOptions.platformAccessModeFlagsDiff.insert(.windows.genericWrite)
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
            append: true,
            noFollow: options.noFollow, 
            closeOnExec: options.closeOnExec,
            noBlocking: false
        )

        if options.noFollow && options.truncate && creationOption != .assertMissing {
            openOptions.platformAccessModeFlagsDiff.insert(.windows.genericWrite)
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
    #endif


    public consuming func close() throws(PlatformError) {
        do {
            try handle.close()
        } catch {
            throw .init(lowLevelError: error, operation: .closeHandle(originalPath: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ body: (borrowing UnsafeSystemHandle) throws(E) -> R
    ) throws(E) -> R {
        try body(handle)
    }

}



extension AppendHandle {

    @discardableResult
    public func append(_ buffer: RawSpan) throws(PlatformError) -> Int64 {

        try buffer.withUnsafeBytes { buffer throws(PlatformError) in
            try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
                #if canImport(WinSDK)
                try handle.pwrite(contentsOf: buffer, to: -1)
                #else
                try handle.write(contentsOf: buffer)
                #endif
            }
        }

    }

}
