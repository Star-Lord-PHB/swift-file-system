import PlatformCLib


extension UnsafeSystemHandle {

    package func reOpenForDir() throws(LowLevelError) -> sending UnsafeSystemHandle {
        return try self.unownedHandle().reOpenForDir()
    }


    #if canImport(WinSDK)
    package func reOpen(
        withAccess access: WindowsAccessMask, 
        openOptions: ULONG = 0
    ) throws(LowLevelError) -> sending UnsafeSystemHandle {
        return try self.unownedHandle().reOpen(withAccess: access, openOptions: openOptions)
    }
    #endif

}



extension UnsafeUnownedSystemHandle {

    package func reOpenForDir() throws(LowLevelError) -> sending UnsafeSystemHandle {

        #if canImport(WinSDK)

        return try reOpen(
            withAccess: [.listDirectory, .readAttributes, .synchronize], 
            openOptions: ULONG(FILE_DIRECTORY_FILE | FILE_SYNCHRONOUS_IO_NONALERT | FILE_OPEN_FOR_BACKUP_INTENT)
        )

        #else

        let newHandle = openat(unsafeRawHandle, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard newHandle >= 0 else {
            try LowLevelError.assertError()
        }
        
        // This new handle is completely independent of the original one, so we can safely send it
        nonisolated(unsafe) let reOpenHandle = UnsafeSystemHandle(owningRawHandle: newHandle)
        return reOpenHandle

        #endif

    }


    #if canImport(WinSDK)
    package func reOpen(
        withAccess access: WindowsAccessMask,
        openOptions: ULONG = 0
    ) throws(LowLevelError) -> sending UnsafeSystemHandle {
        
        let newHandle = ReOpenHandle(unsafeRawHandle, access.rawValue, openOptions)

        guard let newHandle, newHandle != INVALID_HANDLE_VALUE else {
            try LowLevelError.assertError()
        }

        // This new handle is completely independent of the original one, so we can safely send it
        nonisolated(unsafe) let reOpenHandle = UnsafeSystemHandle(owningRawHandle: newHandle)
        return reOpenHandle

    }
    #endif

}
