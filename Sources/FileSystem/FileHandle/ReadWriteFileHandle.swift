import Foundation
import SystemPackage

#if canImport(WinSDK)
import Synchronization
import WinSDK
#endif


public struct ReadWriteFileHandle: ~Copyable, ReadWriteFileHandleProtocol {

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



extension ReadWriteFileHandle {

    public init(forFileAt path: FilePath, options: FileOperationOptions.OpenForWriting = .editFile()) throws(FileError) {

        #if canImport(WinSDK)
        let noBlocking = true 
        #else 
        let noBlocking = false
        #endif

        let handle = try catchSystemError(operationDescription: .openingHandle(forFileAt: path)) { () throws(SystemError) in
            try UnsafeSystemHandle.open(
                at: path, 
                openOptions: options.unsafeSystemFileOpenOptions(noBlocking: noBlocking)
            )
        }

        self.init(unsafeSystemHandle: handle, path: path)

    }


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: UnsafeSystemHandle.SeekWhence) throws(FileError) -> Int64 {

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

        try catchSystemError(operationDescription: .seekingHandle(at: path, to: offset, relativeTo: whence)) { () throws(SystemError) in
            try handle.seek(to: offset, from: whence)
        }

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



extension ReadWriteFileHandle {

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

        try catchSystemError(operationDescription: .readingHandle(at: path, offset: offset, length: Int64(lengthToRead))) { () throws(SystemError) in 
            if let offset {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    _ = try handle.pread(into: bufferPtr, from: offset)
                }
            } else {
                try buffer.withUnsafeMutableBytes { (bufferPtr) throws(SystemError) in
                    _ = try handle.read(into: bufferPtr)
                }
            }
        }

    #endif

    }

}



extension ReadWriteFileHandle {

    public func write(_ data: some ContiguousBytes, toOffset offset: Int64?) throws(FileError) -> Int64 {

        let count = data.withUnsafeBytes { $0.count }
        
    #if canImport(WinSDK)

        var bytesWritten = 0 as DWORD 

        if let offset {
            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(offset & 0xFFFFFFFF)
            overlapped.OffsetHigh = DWORD((offset >> 32) & 0xFFFFFFFF)
            _ = data.withUnsafeBytes { bufferPtr in
                WriteFile(handle.unsafeRawHandle, bufferPtr.baseAddress, DWORD(count), &bytesWritten, &overlapped)
            }
            try execThrowingCFunction(operationDescription: .writingHandle(at: path, offset: offset, length: Int64(count))) {
                GetOverlappedResult(handle.unsafeRawHandle, &overlapped, &bytesWritten, true)
            }
        } else {
            let currentOffset = _currentOffset.withLock(\.self)
            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(currentOffset & 0xFFFFFFFF)
            overlapped.OffsetHigh = DWORD((currentOffset >> 32) & 0xFFFFFFFF)
            _ = data.withUnsafeBytes { bufferPtr in
                WriteFile(handle.unsafeRawHandle, bufferPtr.baseAddress, DWORD(count), &bytesWritten, &overlapped)
            }
            try execThrowingCFunction(operationDescription: .writingHandle(at: path, offset: offset, length: Int64(count))) {
                GetOverlappedResult(handle.unsafeRawHandle, &overlapped, &bytesWritten, true)
            }
            _currentOffset.withLock {
                $0 = currentOffset + Int64(bytesWritten)
            }
        }

        return Int64(bytesWritten)

    #else

        return try data.withUnsafeBytesTypedThrow { bufferPtr throws(FileError) in
            try catchSystemError(operationDescription: .writingHandle(at: path, offset: offset, length: Int64(bufferPtr.count))) { () throws(SystemError) in
                if let offset {
                    return try handle.pwrite(contentsOf: bufferPtr, to: offset)
                } else {
                    return try handle.write(contentsOf: bufferPtr)
                }
            }
        }

    #endif 

    }


    public func resize(to size: Int64) throws(FileError) {
        
        try catchSystemError(operationDescription: .resizingHandle(at: path, toSize: size)) { () throws(SystemError) in
            try handle.truncate(to: size)
        }

    }


    public func synchronize() throws(FileError) {
        
        try catchSystemError(operationDescription: .synchronizingHandle(at: path)) { () throws(SystemError) in
            try handle.fsync()
        }

    }

}