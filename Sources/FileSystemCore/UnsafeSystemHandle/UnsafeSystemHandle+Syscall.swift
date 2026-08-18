import SystemPackage
import PlatformCLib



extension UnsafeSystemHandle {

    /// Opens a system file handle at the specified path using the given open options
    /// 
    /// - Parameter path: The path to the file to open.
    /// - Parameter openOptions: The options to use when opening the file.
    /// - Parameter creationPermissions: The permissions to use when creating the file. 
    ///             Ignored if file creation is not requested.
    /// 
    /// - Returns: An ``UnsafeSystemHandle`` representing the opened file handle.
    /// 
    /// ### Creation Permissions Behavior
    /// 
    /// On both Windows and Posix platforms, the [`FilePermissions`] from swift-system is used to specify 
    /// the permissions when creating a new file, but it behaves differently on the two platforms.
    /// 
    /// On Posix, it is mapped directly to the standard file mode bits. If specified as `nil` while creation
    /// is requested, it will be defaulted to `0o644` (rw-r--r--).
    /// 
    /// On Windows, the permissions will be mapped to a DACL with the best effect with the following rules:
    /// 
    /// | Posix Permission Identity | Mapped Win ACE Identity |
    /// | -- | -- |
    /// | Owner | Current User |
    /// | Group | Primary Group of Current User |
    /// | Other | "Everyone" Group |
    /// 
    /// | Posix Permission | Mapped Win Permission |
    /// | -- | -- |
    /// | Read | FILE_READ_ATTRIBUTES | FILE_READ_EA | FILE_READ_DATA | STANDARD_RIGHTS_READ | SYNCHRONIZE |
    /// | Write | FILE_WRITE_ATTRIBUTES | FILE_WRITE_EA | FILE_WRITE_DATA | STANDARD_RIGHTS_WRITE | SYNCHRONIZE |
    /// | Execute | FILE_EXECUTE | STANDARD_RIGHTS_EXECUTE | SYNCHRONIZE |
    /// 
    /// Such mapping is not exactly the same as the semantics of Posix file mode. For example, 0o044 means that 
    /// anyone can read the file except the owner. However, on Windows, the owner will also have read access.
    /// 
    /// Beside the difference in permission semantics, the default value behavior (when `creationPermissions` 
    /// paramater is set to `nil`) is also different, as described in the table below:
    /// 
    /// | Platform | Default Creation Permissions |
    /// | -- | -- |
    /// | Posix | 0o644 (rw-r--r--) |
    /// | Windows | Inherited from Parent Directory |
    /// 
    /// - SeeAlso: ``UnsafeSystemHandle/OpenOptions``
    /// 
    /// [`FilePermissions`]: https://swiftpackageindex.com/apple/swift-system/documentation/systempackage/filepermissions
    public static func open(
        at path: FilePath, 
        openOptions: OpenOptions = .init(),
        creationPermissions: FilePermissions? = nil
    ) throws(LowLevelError) -> UnsafeSystemHandle {

        #if canImport(WinSDK)

        if openOptions.openFlags & DWORD(FILE_FLAG_OPEN_REPARSE_POINT) != 0
           && openOptions.truncate
           && openOptions.creation != .assertMissing
           && openOptions.platformCreationFlagsOverride == nil {
            // On Windows, opening a symlink with truncate may erase the symlink to a regular file
            // To avoid this, we need to delay the truncate operation after opening the handle, which need to be done by
            // the caller themselves.
            throw .init(kind: .unsupported)
        }

        var securityAttributes = openOptions.securityAttributes

        // Set up security descriptor only when file creation may occur. 
        if openOptions.willCreate, let creationPermissions {
            let sd = try WindowsAbsoluteSecurityDescriptor.makeForCurrentUser(fromPosixPermissions: creationPermissions)
            securityAttributes.lpSecurityDescriptor = .init(sd.psd.unsafeRawPtr)
        }

        let handle = path.withPlatformString { cStr in
            CreateFileW(
                cStr, 
                openOptions.accessModeFlags, 
                openOptions.windowsShareMode.rawValue, 
                &securityAttributes, 
                openOptions.creationFlags,
                openOptions.openFlags,
                nil
            )
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try LowLevelError.assertError()
        }

        return .init(owningRawHandle: handle)

        #else 

        let flags = openOptions.accessModeFlags | openOptions.creationFlags | openOptions.openFlags

        let handle = if openOptions.willCreate {
            // on Posix, when creating file is requested, there must be a creation permission specified,
            // if not, use default permission 0o644 (rw-r--r--)
            path.withPlatformString { strPtr in 
                PlatformCLib.open(strPtr, flags, (creationPermissions ?? [.ownerReadWrite, .groupRead, .otherRead]).rawValue)
            }
        } else {
            path.withPlatformString { strPtr in 
                PlatformCLib.open(strPtr, flags)
            }
        }
        guard handle >= 0 else {
            try LowLevelError.assertError()
        }

        return .init(owningRawHandle: handle)

        #endif 

    }


    #if canImport(WinSDK)
    public static func open(
        at path: FilePath, 
        openOptions: OpenOptions = .init(), 
        creationPermissions: WindowsSecurityDescriptorView
    ) throws(LowLevelError) -> UnsafeSystemHandle {

        if openOptions.openFlags & DWORD(FILE_FLAG_OPEN_REPARSE_POINT) != 0
           && openOptions.truncate
           && openOptions.creation != .assertMissing
           && openOptions.platformCreationFlagsOverride == nil {
            // On Windows, opening a symlink with truncate may erase the symlink to a regular file
            // To avoid this, we need to delay the truncate operation after opening the handle, which need to be done by
            // the caller themselves.
            throw .init(kind: .unsupported)
        }

        var securityAttributes = openOptions.securityAttributes
        securityAttributes.lpSecurityDescriptor = .init(creationPermissions.psd.unsafelyCastedMutableRawPtr)

        let handle = path.withPlatformString { cStr in
            CreateFileW(
                cStr, 
                openOptions.accessModeFlags, 
                openOptions.windowsShareMode.rawValue, 
                &securityAttributes, 
                openOptions.creationFlags,
                openOptions.openFlags,
                nil
            )
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try LowLevelError.assertError()
        }

        return .init(owningRawHandle: handle)

    }


    public static func open(
        at path: FilePath, 
        openOptions: OpenOptions = .init(), 
        creationPermissions: borrowing WindowsAbsoluteSecurityDescriptor
    ) throws(LowLevelError) -> UnsafeSystemHandle {
        return try open(at: path, openOptions: openOptions, creationPermissions: creationPermissions.view)
    }


    public static func open(
        at path: FilePath, 
        openOptions: OpenOptions = .init(), 
        creationPermissions: borrowing WindowsSelfRelativeSecurityDescriptor
    ) throws(LowLevelError) -> UnsafeSystemHandle {
        return try open(at: path, openOptions: openOptions, creationPermissions: creationPermissions.view)
    }
    #endif 


    public static func openDir(at path: FilePath) throws(LowLevelError) -> UnsafeSystemHandle {

        #if canImport(WinSDK)

        let openFlags = DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS)

        let handle = path.withPlatformString { cStr in
            CreateFileW(cStr, GENERIC_READ, DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), nil, DWORD(OPEN_EXISTING), openFlags, nil)
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try LowLevelError.assertError()
        }

        return .init(owningRawHandle: handle)

        #else

        let handle = PlatformCLib.open(path.string, O_RDONLY | O_DIRECTORY)
        guard handle >= 0 else {
            try LowLevelError.assertError()
        }

        return .init(owningRawHandle: handle)
        
        #endif 

    }


    @discardableResult
    public func seek(to offset: Int64, from whence: FileOperationOptions.SeekWhence = .beginning) throws(LowLevelError) -> Int64 {

        #if canImport(WinSDK)

        var newOffset = LARGE_INTEGER()
        
        try execThrowingCFunction {
            SetFilePointerEx(unsafeRawHandle, LARGE_INTEGER(QuadPart: offset), &newOffset, DWORD(whence.rawValue))
        } onError: { () throws(LowLevelError) in
            let error = LowLevelError.fromLastError()
            switch error?.systemCode {
                case .negativeSeek: throw error!.overridingKind(.invalidInput)
                default: throw error ?? .unknown
            }
        }

        return newOffset.QuadPart

        #else 

        let newOffset = lseek(self.unsafeRawHandle, off_t(offset), whence.rawValue)
        guard newOffset >= 0 else {
            try LowLevelError.assertError()
        }

        return Int64(newOffset)

        #endif 

    }


    public func tell() throws(LowLevelError) -> Int64 {
        return try self.seek(to: 0, from: .current)
    }


    public func read(into buffer: UnsafeMutableRawBufferPointer) throws(LowLevelError) -> Int64 {

        let lengthToRead = buffer.count

        #if canImport(WinSDK)

        var bytesRead = 0 as DWORD

        try execThrowingCFunction {
            ReadFile(unsafeRawHandle, buffer.baseAddress, DWORD(lengthToRead), &bytesRead, nil)
        }

        return Int64(bytesRead)

        #else 

        let bytesRead = PlatformCLib.read(self.unsafeRawHandle, buffer.baseAddress, lengthToRead)
        guard bytesRead >= 0 else {
            try LowLevelError.assertError()
        }

        return Int64(bytesRead)

        #endif

    }
    
    
    public func read(into buffer: UnsafeMutableRawBufferPointer.SubSequence) throws(LowLevelError) -> Int64 {
        return try self.read(into: .init(rebasing: buffer))
    }
    
    
    public func read(into buffer: inout MutableRawSpan) throws(LowLevelError) -> Int64 {
        return try buffer.withUnsafeMutableBytes { ptr throws(LowLevelError) in
            try self.read(into: ptr)
        }
    }


    public func read(into buffer: consuming MutableRawSpan) throws(LowLevelError) -> Int64 {
        return try self.read(into: &buffer)
    }


    public func pread(into buffer: UnsafeMutableRawBufferPointer, from offset: Int64) throws(LowLevelError) -> Int64 {

        let lengthToRead = buffer.count

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
            try LowLevelError.assertError()
        }

        return Int64(bytesRead)

        #endif 

    }
    
    
    public func pread(into buffer: UnsafeMutableRawBufferPointer.SubSequence, from offset: Int64) throws(LowLevelError) -> Int64 {
        return try self.pread(into: .init(rebasing: buffer), from: offset)
    }
    
    
    public func pread(into buffer: inout MutableRawSpan, from offset: Int64) throws(LowLevelError) -> Int64 {
        return try buffer.withUnsafeMutableBytes { ptr throws(LowLevelError) in
            try self.pread(into: ptr, from: offset)
        }
    }


    public func pread(into buffer: consuming MutableRawSpan, from offset: Int64) throws(LowLevelError) -> Int64 {
        return try self.pread(into: &buffer, from: offset)
    }


    @discardableResult
    public func write(contentsOf buffer: UnsafeRawBufferPointer) throws(LowLevelError) -> Int64 {

        #if canImport(WinSDK)

        var bytesWritten = 0 as DWORD

        try execThrowingCFunction {
            WriteFile(unsafeRawHandle, buffer.baseAddress, DWORD(buffer.count), &bytesWritten, nil)
        }

        return Int64(bytesWritten)

        #else 

        let bytesWritten = PlatformCLib.write(self.unsafeRawHandle, buffer.baseAddress, buffer.count)
        guard bytesWritten >= 0 else {
            try LowLevelError.assertError()
        }

        return Int64(bytesWritten)

        #endif 

    }
    
    
    @discardableResult
    public func write(contentsOf buffer: UnsafeRawBufferPointer.SubSequence) throws(LowLevelError) -> Int64 {
        return try self.write(contentsOf: .init(rebasing: buffer))
    }
    
    
    @discardableResult
    public func write(contentsOf buffer: RawSpan) throws(LowLevelError) -> Int64 {
        return try buffer.withUnsafeBytes { ptr throws(LowLevelError) in
            try self.write(contentsOf: ptr)
        }
    }


    @discardableResult
    public func pwrite(contentsOf buffer: UnsafeRawBufferPointer, to offset: Int64) throws(LowLevelError) -> Int64 {

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
            try LowLevelError.assertError()
        }

        return Int64(bytesWritten)

        #endif

    }
    
    
    @discardableResult
    public func pwrite(contentsOf buffer: UnsafeRawBufferPointer.SubSequence, to offset: Int64) throws(LowLevelError) -> Int64 {
        return try self.pwrite(contentsOf: .init(rebasing: buffer), to: offset)
    }
    
    
    @discardableResult
    public func pwrite(contentsOf buffer: RawSpan, to offset: Int64) throws(LowLevelError) -> Int64 {
        return try buffer.withUnsafeBytes { ptr throws(LowLevelError) in
            try self.pwrite(contentsOf: ptr, to: offset)
        }
    }


    public func fsync() throws(LowLevelError) {

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


    public func truncate(to offset: Int64) throws(LowLevelError) {

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


    public func truncate() throws(LowLevelError) {
        #if canImport(WinSDK)
        try execThrowingCFunction {
            SetEndOfFile(self.unsafeRawHandle)
        }
        #else 
        try truncate(to: tell())
        #endif
    }


    public func duplicate() throws(LowLevelError) -> UnsafeSystemHandle {

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
            try LowLevelError.assertError()
        }

        return .init(owningRawHandle: newHandle)

        #else 

        let newHandle = dup(self.unsafeRawHandle)
        guard newHandle >= 0 else {
            try LowLevelError.assertError()
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


    public static func pipe() throws(LowLevelError) -> PipeHandles {

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
            try LowLevelError.assertError()
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



extension UnsafeUnownedSystemHandle {

    package func duplicate() throws(LowLevelError) -> UnsafeSystemHandle {

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
            try LowLevelError.assertError()
        }

        return .init(owningRawHandle: newHandle)

        #else 

        let newHandle = dup(self.unsafeRawHandle)
        guard newHandle >= 0 else {
            try LowLevelError.assertError()
        }

        return .init(owningRawHandle: newHandle)

        #endif

    }

}
