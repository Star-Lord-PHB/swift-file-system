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

        let handle: UnsafeUnownedSystemHandle
        public let path: FilePath

        public private(set) var currentOffset: Int64 = 0


        @_lifetime(borrow readHandle)
        init(readHandle: borrowing ReadFileHandle) {
            self.handle = readHandle.handle.unownedHandle()
            self.path = readHandle.path
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


        @_lifetime(self: copy self)
        @_lifetime(buffer: copy buffer)
        public mutating func read(into buffer: inout MutableRawSpan) throws(PlatformError) -> Int64 {
            try catchLowLevelError(operation: .readHandle(originalPath: path)) { () throws(LowLevelError) in
                try self.handle.unsafeTemporaryConvertingToOwning { handle throws(LowLevelError) in
                    do throws(LowLevelError) {
                        let currentOffset = self.currentOffset
                        let bytesRead = try handle.pread(into: &buffer, from: currentOffset)
                        self.currentOffset = currentOffset + bytesRead
                        return bytesRead
                    } catch {
                        #if canImport(WinSDK)
                        if error.systemCode == .handleEOF { return 0 }
                        #endif
                        throw error
                    }
                }
            }
        }

    }

}
