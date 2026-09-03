import struct SystemPackage.FilePath
import FileSystemCore



public struct ReadFileHandle
: ~Copyable, @unchecked Sendable
, PositionalReadFileHandleProtocol, SystemHandleSupportedFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle 
    public let path: FilePath


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension ReadFileHandle {

    public init(forFileAt path: FilePath, options: FileOperationOptions.OpenForReading = .init()) throws(PlatformError) {

        let openOptions = UnsafeSystemHandle.OpenOptions(
            access: .readOnly(),
            noFollow: options.noFollow,
            closeOnExec: options.closeOnExec
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

        self.init(unsafeSystemHandle: handle, path: path)

    }


    package consuming func takeUnsafeSystemHandle() -> UnsafeSystemHandle {
        self.handle
    }


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
    public func sequentialReader() -> SequentialReader {
        .init(readHandle: self)
    }

}



extension ReadFileHandle {

    public struct SequentialReader
    : ~Escapable
    , MutatingSequentialReadFileHandleProtocol, MutatingSeekableFileHandleProtocol
    , SystemHandleSupportedFileHandleProtocol {

        private var accessor: PositionalHandleAccessor

        public var path: FilePath { accessor.path }
        public var currentOffset: Int64 { accessor.currentOffset }


        @_lifetime(borrow readHandle)
        init(readHandle: borrowing ReadFileHandle) {
            self.accessor = .init(handle: readHandle.handle, path: readHandle.path)
        }


        public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
            try accessor.withUnsafeSystemHandle(body)
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
