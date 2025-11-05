import SystemPackage
import PlatformCLib



extension UnsafeSystemHandle {

    public static func open(
        at path: FilePath, 
        openOptions: OpenOptions = .init(),
        creationPermissions: FilePermissions? = nil
    ) throws(SystemError) -> UnsafeSystemHandle {

        #if canImport(WinSDK)
        
        var securityAttributes = openOptions.securityAttributes

        // Set up security descriptor only when file creation may occur. 
        let securityDescriptorPtr = if openOptions.creation != .never, let creationPermissions {
            try WindowsAPI.securityDescriptor(fromPosixPermissions: creationPermissions)
        } else {
            nil as UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>?
        }

        // currently, borrowing switch is the only way to get the unsafeRawPtr in WindowsOwnedAPIPointer
        switch securityDescriptorPtr {
            case .some(let sdPtr):
                securityAttributes.lpSecurityDescriptor = .init(sdPtr.unsafeRawPtr)
            case .none: break
        }

        let handle = path.string.withCString(encodedAs: UTF16.self) { cStr in
            CreateFileW(
                cStr, 
                openOptions.accessModeFlags, 
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), 
                &securityAttributes, 
                openOptions.creationFlags,
                openOptions.openFlags,
                nil
            )
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: handle)

        #else 

        let flags = openOptions.accessModeFlags | openOptions.creationFlags | openOptions.openFlags

        let handle = if let creationPermissions {
            PlatformCLib.open(path.string, flags, creationPermissions.rawValue)
        } else {
            PlatformCLib.open(path.string, flags)
        }
        guard handle >= 0 else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: handle)

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

        let handle = PlatformCLib.open(path.string, O_RDONLY | O_DIRECTORY)
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

        let bytesRead = PlatformCLib.read(self.unsafeRawHandle, buffer.baseAddress, lengthToRead)
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

        var overlapped = OVERLAPPED()
        overlapped.Offset = DWORD(offset & 0xFFFFFFFF)
        overlapped.OffsetHigh = DWORD((offset >> 32) & 0xFFFFFFFF)

        var bytesRead = 0 as DWORD

        try execThrowingCFunction {
            ReadFile(unsafeRawHandle, buffer.baseAddress, DWORD(lengthToRead), &bytesRead, &overlapped)
        }

        return Int64(bytesRead)

        #else 

        let bytesRead = PlatformCLib.pread(self.unsafeRawHandle, buffer.baseAddress, lengthToRead, off_t(offset))
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

        let bytesWritten = PlatformCLib.write(self.unsafeRawHandle, buffer.baseAddress, buffer.count)
        guard bytesWritten >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesWritten)

        #endif 

    }


    @discardableResult
    public func pwrite(contentsOf buffer: UnsafeRawBufferPointer, to offset: Int64) throws(SystemError) -> Int64 {

        #if canImport(WinSDK)

        var overlapped = OVERLAPPED()
        overlapped.Offset = DWORD(offset & 0xFFFFFFFF)
        overlapped.OffsetHigh = DWORD((offset >> 32) & 0xFFFFFFFF)
        var bytesWritten = 0 as DWORD
        try execThrowingCFunction {
            WriteFile(unsafeRawHandle, buffer.baseAddress, DWORD(buffer.count), &bytesWritten, &overlapped)
        }
        return Int64(bytesWritten)

        #else

        let bytesWritten = PlatformCLib.pwrite(self.unsafeRawHandle, buffer.baseAddress, buffer.count, off_t(offset))
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
            PlatformCLib.fsync(self.unsafeRawHandle)
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



extension UnsafeSystemHandle {

    public struct PipeHandles: ~Copyable {
        public let readHandle: UnsafeSystemHandle
        public let writeHandle: UnsafeSystemHandle
    }


    public static func pipe() throws(SystemError) -> PipeHandles {

        #if canImport(WinSDK)

        var readHandle: HANDLE? = nil
        var writeHandle: HANDLE? = nil
        var securityAttributes = SECURITY_ATTRIBUTES(
            nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
            lpSecurityDescriptor: nil,
            bInheritHandle: true
        )

        try execThrowingCFunction {
            CreatePipe(&readHandle, &writeHandle, &securityAttributes, 0)
        }
        guard let readHandle, let writeHandle else {
            try SystemError.assertError()
        }

        return .init(readHandle: .init(owningRawHandle: readHandle), writeHandle: .init(owningRawHandle: writeHandle))

        #else 

        var fds = [0, 0] as [CInt]

        try execThrowingCFunction {
            PlatformCLib.pipe(&fds)
        }

        var readHandle = UnsafeSystemHandle(owningRawHandle: fds[0])
        var writeHandle = UnsafeSystemHandle(owningRawHandle: fds[1])

        return .init(readHandle: readHandle, writeHandle: writeHandle)

        #endif 

    }

}