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

        fatalError("Not implemented")
        #warning("Not implemented")

        #else 

        let flags = openOptions.accessModeFlags | openOptions.creationFlags | openOptions.openFlags

        let handle = Foundation.open(path.string, flags, creationPermissions.rawValue)
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
            CreateFileW(cStr, GENERIC_READ, DWORD(FILE_SHARE_READ), nil, DWORD(OPEN_EXISTING), openFlags, nil)
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

        fatalError("Not implemented")
        #warning("Not implemented")

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
    public func read(into buffer: UnsafeMutableRawBufferPointer) throws(SystemError) -> Int64 {

        #if canImport(WinSDK)

        fatalError("Not implemented")
        #warning("Not implemented")

        #else 

        let bytesRead = Foundation.read(self.unsafeRawHandle, buffer.baseAddress, buffer.count)
        guard bytesRead >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesRead)

        #endif

    }


    #if !canImport(WinSDK)
    @discardableResult
    public func pread(into buffer: UnsafeMutableRawBufferPointer, from offset: Int64) throws(SystemError) -> Int64 {

        let bytesRead = Foundation.pread(self.unsafeRawHandle, buffer.baseAddress, buffer.count, off_t(offset))
        guard bytesRead >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesRead)

    }
    #endif 


    @discardableResult
    public func write(contentsOf buffer: UnsafeRawBufferPointer) throws(SystemError) -> Int64 {

        #if canImport(WinSDK)

        fatalError("Not implemented")
        #warning("Not implemented")

        #else 

        let bytesWritten = Foundation.write(self.unsafeRawHandle, buffer.baseAddress, buffer.count)
        guard bytesWritten >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesWritten)

        #endif 

    }


    #if !canImport(WinSDK)
    @discardableResult
    public func pwrite(contentsOf buffer: UnsafeRawBufferPointer, to offset: Int64) throws(SystemError) -> Int64 {

        let bytesWritten = Foundation.pwrite(self.unsafeRawHandle, buffer.baseAddress, buffer.count, off_t(offset))
        guard bytesWritten >= 0 else {
            try SystemError.assertError()
        }

        return Int64(bytesWritten)

    }
    #endif


    public func fsync() throws(SystemError) {

        #if canImport(WinSDK)

        fatalError("Not implemented")
        #warning("Not implemented")

        #else 

        try execThrowingCFunction {
            Foundation.fsync(self.unsafeRawHandle)
        }

        #endif

    }


    public func truncate(to offset: Int64) throws(SystemError) {

        #if canImport(WinSDK)

        fatalError("Not implemented")
        #warning("Not implemented")

        #else 

        try execThrowingCFunction {
            ftruncate(self.unsafeRawHandle, off_t(offset))
        }

        #endif

    }


    public func truncate() throws(SystemError) {
        #if canImport(WinSDK)
        fatalError("Not implemented")
        #warning("Not implemented")
        #else 
        try truncate(to: tell())
        #endif
    }


    public func duplicate() throws(SystemError) -> UnsafeSystemHandle {

        #if canImport(WinSDK)

        fatalError("Not implemented")
        #warning("Not implemented")

        #else 

        let newHandle = dup(self.unsafeRawHandle)
        guard newHandle >= 0 else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: newHandle)

        #endif

    }

}