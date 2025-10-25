import Foundation
import SystemPackage

#if canImport(WinSDK)
import WinSDK
import Synchronization
#endif


public struct ReadFileHandle: ~Copyable, ReadFileHandleProtocol {

    fileprivate let handle: UnsafeSystemHandle 
    public let path: FilePath

    #if canImport(WinSDK)
    // On windows, there is not direct way to allow random access (similar to pread in POSIX) 
    // while allowing accessing with system file pointer. So we track the current offset manually.
    private let _currentOffset: Mutex<Int64> = Mutex(0)
    public var currentOffset: Int64 {
        get throws(FileError) {
            _currentOffset.withLock(\.self)
        }
    }
    #endif 


    init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) {
        self.handle = unsafeSystemHandle
        self.path = path
    }

}



extension ReadFileHandle {

    public init(forFileAt path: FilePath) throws(FileError) {

        #if canImport(WinSDK)

        let openFlags = DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED | FILE_FLAG_BACKUP_SEMANTICS)

        let handle = path.string.withCString(encodedAs: UTF16.self) { cStr in
            CreateFileW(cStr, GENERIC_READ, DWORD(FILE_SHARE_READ), nil, DWORD(OPEN_EXISTING), openFlags, nil)
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }

        self.init(unsafeSystemHandle: .init(owningRawHandle: handle), path: path)

        #else

        let handle = open(path.string, O_RDONLY)
        guard handle >= 0 else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }

        self.init(unsafeSystemHandle: .init(owningRawHandle: handle), path: path)

        #endif

    }


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileSeekWhence = .beginning) throws(FileError) -> Int64 {

        #if canImport(WinSDK)

        switch whence {
            case .beginning:
                return _currentOffset.withLock { 
                    $0 = offset 
                    return $0
                }
            case .current:
                return _currentOffset.withLock { 
                    $0 += offset 
                    return $0
                }
            case .end:
                var size = LARGE_INTEGER(QuadPart: 0)
                try execThrowingCFunction(operationDescription: .seekingHandle(at: path, to: offset, relativeTo: whence)) {
                    GetFileSizeEx(handle.unsafeRawHandle, &size)
                }
                return _currentOffset.withLock {
                    $0 = size.QuadPart + offset
                    return $0
                }
        }

        #else 

        let newOffset = lseek(handle.unsafeRawHandle, .init(offset), whence.rawValue)
        guard newOffset >= 0 else {
            try FileError.assertError(operationDescription: .seekingHandle(at: path, to: offset, relativeTo: whence))
        }
        return Int64(newOffset)
        
        #endif
    }


    public consuming func close() throws(FileError) {
        do {
            try handle.close()
        } catch {
            throw .init(systemError: error, operationDescription: .closingHandle(at: path))
        }
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R {
        try body(handle)
    }

}



extension ReadFileHandle {

    public func read(fromOffset offset: Int64?, length: Int64?, into buffer: inout ByteBuffer) throws(FileError) {

        let lengthToRead = min(buffer.count, length.map { Int($0) } ?? buffer.count)

    #if canImport(WinSDK)

        var bytesRead = 0 as DWORD

        if let offset {
            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(offset & 0xFFFFFFFF)
            overlapped.OffsetHigh = DWORD((offset >> 32) & 0xFFFFFFFF)
            _ = buffer.withUnsafeMutableBytes { bufferPtr in
                ReadFile(handle.unsafeRawHandle, bufferPtr.baseAddress, DWORD(lengthToRead), &bytesRead, &overlapped)
            }
            try execThrowingCFunction(operationDescription: .readingHandle(at: path, offset: offset, length: Int64(lengthToRead))) {
                GetOverlappedResult(handle.unsafeRawHandle, &overlapped, &bytesRead, true)
            }
        } else {
            let currentOffset = _currentOffset.withLock(\.self)
            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(currentOffset & 0xFFFFFFFF)
            overlapped.OffsetHigh = DWORD((currentOffset >> 32) & 0xFFFFFFFF)
            _ = buffer.withUnsafeMutableBytes { bufferPtr in
                ReadFile(handle.unsafeRawHandle, bufferPtr.baseAddress, DWORD(lengthToRead), &bytesRead, &overlapped)
            }
            try execThrowingCFunction(operationDescription: .readingHandle(at: path, offset: offset, length: Int64(lengthToRead))) {
                GetOverlappedResult(handle.unsafeRawHandle, &overlapped, &bytesRead, true)
            }
            _currentOffset.withLock {
                $0 = currentOffset + Int64(bytesRead)
            }
        }

    #else

        let bytesRead = if let offset {
            buffer.withUnsafeMutableBytes { bufferPtr in
                pread(handle.unsafeRawHandle, bufferPtr.baseAddress, lengthToRead, .init(offset))
            }
        } else {
            buffer.withUnsafeMutableBytes { bufferPtr in
                Foundation.read(handle.unsafeRawHandle, bufferPtr.baseAddress, lengthToRead)
            }
        }

        if bytesRead < 0 {
            try FileError.assertError(operationDescription: .readingHandle(at: path, offset: offset, length: Int64(lengthToRead)))
        }

    #endif

    }

}