import Foundation
import SystemPackage

#if canImport(WinSDK)
import Synchronization
import WinSDK
#endif


public struct WriteFileHandle: ~Copyable, WriteFileHandleProtocol {

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



extension WriteFileHandle {

    public init(forFileAt path: FilePath, options: FileOperationOptions.Write = .editFile()) throws(FileError) {

        #if canImport(WinSDK)

        let creationDisposition = switch (options.createFile, options.openFile) {
            case (.none, .direct):                      DWORD(OPEN_EXISTING)
            case (.none, .truncate):                    DWORD(TRUNCATE_EXISTING)
            case (.some(.createIfMissing), .direct):    DWORD(OPEN_ALWAYS)
            case (.some(.createIfMissing), .truncate):  DWORD(CREATE_ALWAYS)
            case (.some(.assertMissing), _):            DWORD(CREATE_NEW)
        }

        let openFlags = DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED | FILE_FLAG_BACKUP_SEMANTICS)

        let handle = path.string.withCString(encodedAs: UTF16.self) { cStr in
            CreateFileW(cStr, DWORD(GENERIC_WRITE), DWORD(FILE_SHARE_READ), nil, creationDisposition, openFlags, nil)
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }

        self.init(unsafeSystemHandle: .init(owningRawHandle: handle), path: path)

        #else

        var flags: CInt = O_WRONLY

        switch options.openFile {
            case .direct:   break
            case .truncate: flags |= O_TRUNC
        }

        switch options.createFile {
            case .none:                     break 
            case .some(.createIfMissing):   flags |= O_CREAT
            case .some(.assertMissing):     flags |= O_EXCL | O_CREAT
        }

        let handle = open(path.string, flags, S_IRUSR | S_IWUSR)
        guard handle >= 0 else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }

        self.init(unsafeSystemHandle: .init(owningRawHandle: handle), path: path)

        #endif

    }


    @discardableResult
    public func seek(to offset: Int64, relativeTo whence: FileSeekWhence) throws(FileError) -> Int64 {

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



extension WriteFileHandle {

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

        let bytesWritten = if let offset {
            data.withUnsafeBytes { bufferPtr in
                pwrite(handle.unsafeRawHandle, bufferPtr.baseAddress, count, .init(offset))
            }
        } else {
            data.withUnsafeBytes { bufferPtr in
                Foundation.write(handle.unsafeRawHandle, bufferPtr.baseAddress, count)
            }
        }

        if bytesWritten < 0 {
            try FileError.assertError(operationDescription: .writingHandle(at: path, offset: offset, length: Int64(count)))
        }

        return Int64(bytesWritten)

    #endif 

    }


    public func resize(to size: Int64) throws(FileError) {
        
    #if canImport(WinSDK)

        var currentGlobalFilePointer = LARGE_INTEGER(QuadPart: 0)
        try execThrowingCFunction(operationDescription: .resizingHandle(at: path, toSize: size)) {
            SetFilePointerEx(handle.unsafeRawHandle, LARGE_INTEGER(QuadPart: 0), &currentGlobalFilePointer, DWORD(FILE_CURRENT))
        }

        try execThrowingCFunction(operationDescription: .resizingHandle(at: path, toSize: size)) {
            SetFilePointerEx(handle.unsafeRawHandle, LARGE_INTEGER(QuadPart: size), nil, DWORD(FILE_BEGIN))
        }

        defer {
            // always try to restore the global file pointer, any error in this stage is ignored
            SetFilePointerEx(handle.unsafeRawHandle, currentGlobalFilePointer, nil, DWORD(FILE_BEGIN))
        }

        try execThrowingCFunction(operationDescription: .resizingHandle(at: path, toSize: size)) {
            SetEndOfFile(handle.unsafeRawHandle)
        }

    #else

        try execThrowingCFunction(operationDescription: .resizingHandle(at: path, toSize: size)) {
            ftruncate(handle.unsafeRawHandle, .init(size))
        }

    #endif

    }


    public func synchronize() throws(FileError) {
        
    #if canImport(WinSDK)

        try execThrowingCFunction(operationDescription: .synchronizingHandle(at: path)) {
            FlushFileBuffers(handle.unsafeRawHandle)
        }

    #else

        try execThrowingCFunction(operationDescription: .synchronizingHandle(at: path)) {
            fsync(handle.unsafeRawHandle)
        }

    #endif

    }

}