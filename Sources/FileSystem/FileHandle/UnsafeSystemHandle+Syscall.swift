import SystemPackage
import Foundation

#if canImport(WinSDK)
import WinSDK
#endif



extension UnsafeSystemHandle {

    public static func open(
        at path: FilePath, 
        openOptions: OpenOptions = .init(),
        creationPermissions: FilePermissions = [.ownerReadWrite, .groupRead, .otherRead]
    ) throws(SystemError) -> UnsafeSystemHandle {

        #if canImport(WinSDK)

        let handle = path.string.withCString(encodedAs: UTF16.self) { cStr in
            CreateFileW(
                cStr, 
                openOptions.accessModeFlags, 
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), 
                nil, 
                openOptions.creationFlags,
                openOptions.openFlags,
                nil
            )
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: handle, isNonBlocking: openOptions.noBlocking)

        #else 

        let flags = openOptions.accessModeFlags | openOptions.creationFlags | openOptions.openFlags

        let handle = Foundation.open(path.string, flags, creationPermissions.rawValue)
        guard handle >= 0 else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: handle, isNonBlocking: openOptions.noBlocking)

        #endif 

    }


    public static func openDir(at path: FilePath) throws(SystemError) -> UnsafeSystemHandle {

        #if canImport(WinSDK)

        let openFlags = DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS)

        let handle = path.string.withCString(encodedAs: UTF16.self) { cStr in
            CreateFileW(cStr, GENERIC_READ, DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), nil, DWORD(OPEN_EXISTING), openFlags, nil)
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: handle)

        #else

        let handle = Foundation.open(path.string, O_RDONLY | O_DIRECTORY)
        guard handle >= 0 else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: handle)
        
        #endif 

    }


    @discardableResult
    public func seek(to offset: Int64, from whence: SeekWhence = .beginning) throws(SystemError) -> Int64 {

        #if canImport(WinSDK)

        var newOffset: LARGE_INTEGER = LARGE_INTEGER()
        
        try execThrowingCFunction {
            SetFilePointerEx(unsafeRawHandle, LARGE_INTEGER(QuadPart: offset), &newOffset, DWORD(whence.rawValue))
        }

        return newOffset.QuadPart

        #else 

        let newOffset = lseek(self.unsafeRawHandle, off_t(offset), whence.rawValue)
        guard newOffset >= 0 else {
            try SystemError.assertError()
        }

        return Int64(newOffset)

        #endif 

    }


    public func tell() throws(SystemError) -> Int64 {
        return try self.seek(to: 0, from: .current)
    }


    @discardableResult
    public func read(into buffer: UnsafeMutableRawBufferPointer, length: Int64? = nil) throws(SystemError) -> Int64 {

        let lengthToRead = min(buffer.count, length.map { Int($0) } ?? buffer.count)

        #if canImport(WinSDK)

        var bytesRead = 0 as DWORD

        try execThrowingCFunction {
            ReadFile(unsafeRawHandle, buffer.baseAddress, DWORD(lengthToRead), &bytesRead, nil)
        }

        return Int64(bytesRead)

        #else 

        let bytesRead = Foundation.read(self.unsafeRawHandle, buffer.baseAddress, lengthToRead)
        guard bytesRead >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesRead)

        #endif

    }


    @discardableResult
    public func pread(into buffer: UnsafeMutableRawBufferPointer, from offset: Int64, length: Int64? = nil) throws(SystemError) -> Int64 {

        let lengthToRead = min(buffer.count, length.map { Int($0) } ?? buffer.count)

        #if canImport(WinSDK)

        if isNonBlocking {
            return try withWindowsOverlapped { (overlapped) throws(SystemError) in
                overlapped.offset = offset
                return try read(into: buffer, length: Int64(lengthToRead), overlapped: &overlapped)
            }
        } else {
            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(offset & 0xFFFFFFFF)
            overlapped.OffsetHigh = DWORD((offset >> 32) & 0xFFFFFFFF)

            var bytesRead = 0 as DWORD

            try execThrowingCFunction {
                ReadFile(unsafeRawHandle, buffer.baseAddress, DWORD(lengthToRead), &bytesRead, &overlapped)
            }

            return Int64(bytesRead)
        }

        #else 

        let bytesRead = Foundation.pread(self.unsafeRawHandle, buffer.baseAddress, lengthToRead, off_t(offset))
        guard bytesRead >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesRead)

        #endif 

    }


    @discardableResult
    public func write(contentsOf buffer: UnsafeRawBufferPointer) throws(SystemError) -> Int64 {

        #if canImport(WinSDK)

        var bytesWritten = 0 as DWORD

        try execThrowingCFunction {
            WriteFile(unsafeRawHandle, buffer.baseAddress, DWORD(buffer.count), &bytesWritten, nil)
        }

        return Int64(bytesWritten)

        #else 

        let bytesWritten = Foundation.write(self.unsafeRawHandle, buffer.baseAddress, buffer.count)
        guard bytesWritten >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesWritten)

        #endif 

    }


    @discardableResult
    public func pwrite(contentsOf buffer: UnsafeRawBufferPointer, to offset: Int64) throws(SystemError) -> Int64 {

        #if canImport(WinSDK)

        if isNonBlocking {
            return try withWindowsOverlapped { (overlapped) throws(SystemError) in
                overlapped.offset = offset
                return try write(contentsOf: buffer, overlapped: &overlapped)
            }
        } else {
            var overlapped = OVERLAPPED()
            overlapped.Offset = DWORD(offset & 0xFFFFFFFF)
            overlapped.OffsetHigh = DWORD((offset >> 32) & 0xFFFFFFFF)
            var bytesWritten = 0 as DWORD
            try execThrowingCFunction {
                WriteFile(unsafeRawHandle, buffer.baseAddress, DWORD(buffer.count), &bytesWritten, &overlapped)
            }
            return Int64(bytesWritten)
        }

        #else

        let bytesWritten = Foundation.pwrite(self.unsafeRawHandle, buffer.baseAddress, buffer.count, off_t(offset))
        guard bytesWritten >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesWritten)

        #endif

    }


    public func fsync() throws(SystemError) {

        #if canImport(WinSDK)

        try execThrowingCFunction {
            FlushFileBuffers(self.unsafeRawHandle)
        }

        #else 

        try execThrowingCFunction {
            Foundation.fsync(self.unsafeRawHandle)
        }

        #endif

    }


    public func truncate(to offset: Int64) throws(SystemError) {

        #if canImport(WinSDK)

        let currentFilePointerOffset = try self.tell()
        defer {
            _ = try? self.seek(to: currentFilePointerOffset, from: .beginning)
        }

        try self.seek(to: offset, from: .beginning)

        try execThrowingCFunction {
            SetEndOfFile(self.unsafeRawHandle)
        }

        #else 

        try execThrowingCFunction {
            ftruncate(self.unsafeRawHandle, off_t(offset))
        }

        #endif

    }


    public func truncate() throws(SystemError) {
        #if canImport(WinSDK)
        try execThrowingCFunction {
            SetEndOfFile(self.unsafeRawHandle)
        }
        #else 
        try truncate(to: tell())
        #endif
    }


    public func duplicate() throws(SystemError) -> UnsafeSystemHandle {

        #if canImport(WinSDK)

        var newHandle: WinSDK.HANDLE? = nil

        try execThrowingCFunction {
            DuplicateHandle(
                GetCurrentProcess(),
                self.unsafeRawHandle,
                GetCurrentProcess(),
                &newHandle,
                0,
                false,
                DWORD(DUPLICATE_SAME_ACCESS)
            )
        }
        guard let newHandle else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: newHandle)

        #else 

        let newHandle = dup(self.unsafeRawHandle)
        guard newHandle >= 0 else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: newHandle)

        #endif

    }

}



#if canImport(WinSDK)
extension UnsafeSystemHandle {

    public struct WindowsOverlapped: ~Copyable {
        private var systemOverlapped: OVERLAPPED
        public init(offset: Int64 = 0, eventHandle: WinSDK.HANDLE? = nil) {
            self.systemOverlapped = OVERLAPPED()
            self.systemOverlapped.Offset = DWORD(offset & 0xFFFFFFFF)
            self.systemOverlapped.OffsetHigh = DWORD((offset >> 32) & 0xFFFFFFFF)
            self.systemOverlapped.hEvent = eventHandle
        }
        public var offset: Int64 {
            get {
                Int64(self.systemOverlapped.Offset) | (Int64(self.systemOverlapped.OffsetHigh) << 32)
            }
            set {
                self.systemOverlapped.Offset = DWORD(newValue & 0xFFFFFFFF)
                self.systemOverlapped.OffsetHigh = DWORD((newValue >> 32) & 0xFFFFFFFF)
            }
        }
        public var eventHandle: WinSDK.HANDLE? {
            get {
                self.systemOverlapped.hEvent
            }
            set {
                self.systemOverlapped.hEvent = newValue
            }
        }
        public func withSystemOverlapped<T: ~Copyable, E: Error>(_ body: (OVERLAPPED) throws(E) -> T) throws(E) -> T {
            return try body(self.systemOverlapped)
        }
        public mutating func withMutableSystemOverlapped<T: ~Copyable, E: Error>(_ body: (inout OVERLAPPED) throws(E) -> T) throws(E) -> T {
            return try body(&self.systemOverlapped)
        }
    }


    public func read(into buffer: UnsafeMutableRawBufferPointer, length: Int64? = nil, overlapped: inout WindowsOverlapped) throws(SystemError) {

        let lengthToRead = min(buffer.count, length.map { Int($0) } ?? buffer.count)

        var bytesRead = 0 as DWORD

        let result = overlapped.withMutableSystemOverlapped { systemOverlapped in
            ReadFile(unsafeRawHandle, buffer.baseAddress, DWORD(lengthToRead), &bytesRead, &systemOverlapped)
        }

        if result == false {
            let errorCode = GetLastError()
            guard errorCode == ERROR_IO_PENDING else {
                throw SystemError(code: errorCode)
            }
        }

    }


    public func write(contentsOf buffer: UnsafeRawBufferPointer, overlapped: inout WindowsOverlapped) throws(SystemError) {

        var bytesWritten = 0 as DWORD

        let result = overlapped.withMutableSystemOverlapped { systemOverlapped in
            WriteFile(unsafeRawHandle, buffer.baseAddress, DWORD(buffer.count), &bytesWritten, &systemOverlapped)
        }

        guard result || GetLastError() == ERROR_IO_PENDING else {
            throw SystemError(code: GetLastError())
        }

        if result == false {
            let errorCode = GetLastError()
            guard errorCode == ERROR_IO_PENDING else {
                throw SystemError(code: errorCode)
            }
        }

    }


    public func waitForOverlappedResult(_ overlapped: inout WindowsOverlapped) throws(SystemError) -> Int64 {

        var bytesTransferred = 0 as DWORD

        try execThrowingCFunction {
            overlapped.withMutableSystemOverlapped { systemOverlapped in
                GetOverlappedResult(unsafeRawHandle, &systemOverlapped, &bytesTransferred, true)
            }
        }

        return Int64(bytesTransferred)

    }


    public func withWindowsOverlapped<T: ~Copyable>(
        _ body: (inout WindowsOverlapped) throws -> Void, 
        onComplete: (_ overlapped: inout WindowsOverlapped, _ bytesTransferred: Int64) throws -> T = { _, bytesTransferred in bytesTransferred }
    ) throws -> T {
        var overlapped = WindowsOverlapped()
        try body(&overlapped)
        let bytesTransferred = try waitForOverlappedResult(&overlapped)
        return try onComplete(&overlapped, bytesTransferred)
    }


    public func withWindowsOverlapped<T: ~Copyable>(
        _ body: (inout WindowsOverlapped) throws(SystemError) -> Void, 
        onComplete: (_ overlapped: inout WindowsOverlapped, _ bytesTransferred: Int64) throws(SystemError) -> T = { _, bytesTransferred in bytesTransferred }
    ) throws(SystemError) -> T {
        var overlapped = WindowsOverlapped()
        try body(&overlapped)
        let bytesTransferred = try waitForOverlappedResult(&overlapped)
        return try onComplete(&overlapped, bytesTransferred)
    }

}
#endif