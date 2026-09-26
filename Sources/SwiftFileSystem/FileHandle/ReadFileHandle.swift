import SystemPackage
import FileSystemCore



/// A file handle for positionally reading a file.
public struct ReadFileHandle
: ~Copyable, @unchecked Sendable
, PositionalReadFileHandleProtocol, SystemHandleSupportedFileHandleProtocol {

    fileprivate let context: UnsafeHandleContext
    public let path: FilePath


    init(unsafeHandleContext: consuming UnsafeHandleContext, path: FilePath) {
        self.context = unsafeHandleContext
        self.path = path
    }

}



extension ReadFileHandle {

    /// Opens a file handle for the file at the specified path.
    /// - Parameters:
    ///   - path: The path of the file to open.
    ///   - options: The options for opening the file handle.
    public init(forFileAt path: FilePath, options: FileOperationOptions.OpenForReading = .init()) throws(PlatformError) {

        let openOptions = UnsafeSystemHandle.OpenOptions(
            access: .readOnly,
            closeOnExec: options.closeOnExec,
            platformOpenFlagsDiff: .inserted(options.noFollow ? [.posix.noFollow, .windows.openReparsePoint] : [])
        )

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.open(at: path, openOptions: openOptions)
        } kindConversion: { error in 
            switch error.systemCode {
                #if canImport(WinSDK)
                case .accessDenied: .windows.permissionDeniedOrIsADirectory
                #endif
                default: error.kind
            }
        }

        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            switch try handle.type() {
                case .symlink: throw .init(kind: .pathResolutionFailed)
                case .directory: throw .init(kind: .isADirectory)
                default: break
            }
        }

        self.init(
            unsafeHandleContext: .init(handle: handle, openOptions: openOptions),
            path: path
        )

    }


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


    /// Gets a sequential reader for this file handle.
    @_lifetime(borrow self)
    public func sequentialReader() -> SequentialReader {
        .init(readHandle: self)
    }

}



extension ReadFileHandle {

    /// A sequential reader supported by a positional read file handle.
    /// 
    /// The sequential read operations provided by this reader are based on a manually maintained file 
    /// pointer instead of relying on the one provided by the underlying file system. As a result, each 
    /// instance have independent file pointer.
    public struct SequentialReader
    : ~Escapable
    , MutatingSequentialReadFileHandleProtocol, MutatingSeekableFileHandleProtocol
    , SystemHandleSupportedFileHandleProtocol {

        private var accessor: PositionalHandleAccessor

        public var path: FilePath { accessor.path }
        public var currentOffset: Int64 { accessor.currentOffset }


        @_lifetime(borrow readHandle)
        init(readHandle: borrowing ReadFileHandle) {
            self.accessor = .init(unsafeHandleContext: readHandle.context, path: readHandle.path)
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

    }

}
