import SystemPackage
import FileSystemCore



public struct AppendHandle: ~Copyable, AppendableFileHandleProtocol {

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

        var openOptions = options.unsafeSystemFileOpenOptions()

        openOptions.append = true
        openOptions.noBlocking = false

        let handle = try catchSystemError(operation: .open(path)) { () throws(SystemError) in
            try UnsafeSystemHandle.open(
                at: path,
                openOptions: openOptions,
                creationPermissions: creationPermissions
            )
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }


    #if canImport(WinSDK)
    public init(
        forFileAt path: FilePath,
        options: FileOperationOptions.OpenForWriting = .editFile(),
        creationPermissions: WindowsSecurityDescriptorView
    ) throws(PlatformError) {

        var openOptions = options.unsafeSystemFileOpenOptions()

        openOptions.append = true
        openOptions.noBlocking = false

        let handle = try catchSystemError(operation: .open(path)) { () throws(SystemError) in
            try UnsafeSystemHandle.open(
                at: path,
                openOptions: openOptions,
                creationPermissions: creationPermissions
            )
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
            throw .init(systemError: error, operation: .closeHandle(originalPath: path))
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
    public func append(_ data: ByteBuffer) throws(PlatformError) -> Int64 {

        try data.withUnsafeBytes { buffer throws(PlatformError) in
            try catchSystemError(operation: .writeHandle(originalPath: path)) { () throws(SystemError) in
                try handle.write(contentsOf: buffer)
            }
        }

    }


    public func synchronize() throws(PlatformError) {

        try catchSystemError(operation: .syncHandle(originalPath: path)) { () throws(SystemError) in
            try handle.fsync()
        }

    }

}
