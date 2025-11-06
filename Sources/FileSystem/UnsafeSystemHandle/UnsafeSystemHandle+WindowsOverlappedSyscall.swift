#if canImport(WinSDK)

import SystemPackage
import WinSDK



extension UnsafeSystemHandle {

    public struct WindowsOverlapped: ~Copyable {

        private var systemOverlapped: OVERLAPPED

        public init(offset: Int64 = 0, eventHandle: WinSDK.HANDLE? = nil) {
            self.systemOverlapped = OVERLAPPED()
            self.systemOverlapped.Offset = DWORD(offset & 0xFFFFFFFF)
            self.systemOverlapped.OffsetHigh = DWORD((offset >> 32) & 0xFFFFFFFF)
            self.systemOverlapped.hEvent = eventHandle
        }

        deinit {
            assert(false, "WindowsOverlapped deinitialized without being explicitly consumed by calling waitForResult(handle:onComplete:)")
        }

        public var offset: Int64 {
            get { Int64(self.systemOverlapped.Offset) | (Int64(self.systemOverlapped.OffsetHigh) << 32) }
            set {
                self.systemOverlapped.Offset = DWORD(newValue & 0xFFFFFFFF)
                self.systemOverlapped.OffsetHigh = DWORD((newValue >> 32) & 0xFFFFFFFF)
            }
        }

        public var eventHandle: WinSDK.HANDLE? {
            get { self.systemOverlapped.hEvent }
            set { self.systemOverlapped.hEvent = newValue }
        }

        public func withSystemOverlapped<T: ~Copyable, E: Error>(_ body: (OVERLAPPED) throws(E) -> T) throws(E) -> T {
            return try body(self.systemOverlapped)
        }

        public mutating func withMutableSystemOverlapped<T: ~Copyable, E: Error>(_ body: (inout OVERLAPPED) throws(E) -> T) throws(E) -> T {
            return try body(&self.systemOverlapped)
        }

        consuming func _waitForResultAndDiscard<R: ~Copyable>(
            handle: borrowing UnsafeSystemHandle,
            onComplete: (_ overlapped: borrowing WindowsOverlapped, _ bytesTransferred: Int64) throws -> R = { _, bytesTransferred in bytesTransferred }
        ) throws -> R {
            var bytesTransferred = 0 as DWORD
            do {
                try execThrowingCFunction {
                    GetOverlappedResult(handle.unsafeRawHandle, &systemOverlapped, &bytesTransferred, true)
                }
                let result = try onComplete(self, Int64(bytesTransferred))
                discard self
                return result
            } catch {
                discard self
                throw error
            }
        }

        consuming func _waitForResultAndDiscard<R: ~Copyable>(
            handle: borrowing UnsafeSystemHandle,
            onComplete: (_ overlapped: borrowing WindowsOverlapped, _ bytesTransferred: Int64) throws(SystemError) -> R = { _, bytesTransferred in bytesTransferred }
        ) throws(SystemError) -> R {
            var bytesTransferred = 0 as DWORD
            do {
                try execThrowingCFunction {
                    GetOverlappedResult(handle.unsafeRawHandle, &systemOverlapped, &bytesTransferred, true)
                }
                let result = try onComplete(self, Int64(bytesTransferred))
                discard self
                return result
            } catch {
                discard self
                throw error
            }
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


    public func waitForOverlappedResult<R: ~Copyable>(
        _ overlapped: consuming WindowsOverlapped,
        onComplete: (_ overlapped: borrowing WindowsOverlapped, _ bytesTransferred: Int64) throws -> R = { _, bytesTransferred in bytesTransferred }
    ) throws -> R {
        return try overlapped._waitForResultAndDiscard(handle: self, onComplete: onComplete)
    }


    public func waitForOverlappedResult<R: ~Copyable>(
        _ overlapped: consuming WindowsOverlapped,
        onComplete: (_ overlapped: borrowing WindowsOverlapped, _ bytesTransferred: Int64) throws(SystemError) -> R = { _, bytesTransferred in bytesTransferred }
    ) throws(SystemError) -> R {
        return try overlapped._waitForResultAndDiscard(handle: self, onComplete: onComplete)
    }


    public func withWindowsOverlapped<T: ~Copyable>(
        _ body: (inout WindowsOverlapped) throws -> Void, 
        onComplete: (_ overlapped: borrowing WindowsOverlapped, _ bytesTransferred: Int64) throws -> T = { _, bytesTransferred in bytesTransferred }
    ) throws -> T {
        var overlapped = WindowsOverlapped()
        try body(&overlapped)
        return try waitForOverlappedResult(overlapped, onComplete: onComplete)
    }


    public func withWindowsOverlapped<T: ~Copyable>(
        _ body: (inout WindowsOverlapped) throws(SystemError) -> Void, 
        onComplete: (_ overlapped: borrowing WindowsOverlapped, _ bytesTransferred: Int64) throws(SystemError) -> T = { _, bytesTransferred in bytesTransferred }
    ) throws(SystemError) -> T {
        var overlapped = WindowsOverlapped()
        try body(&overlapped)
        return try waitForOverlappedResult(overlapped, onComplete: onComplete)
    }

}
#endif