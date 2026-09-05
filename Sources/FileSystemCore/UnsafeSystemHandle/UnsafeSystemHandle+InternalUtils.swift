import PlatformCLib


extension UnsafeSystemHandle {

    package func reOpenForDir() throws(LowLevelError) -> sending UnsafeSystemHandle {
        return try self.unownedHandle().reOpenForDir()
    }

}



extension UnsafeUnownedSystemHandle {

    package func reOpenForDir() throws(LowLevelError) -> sending UnsafeSystemHandle {

        #if canImport(WinSDK)
        let newHandle = ReOpenDir(unsafeRawHandle)
        guard let newHandle, newHandle != INVALID_HANDLE_VALUE else {
            try LowLevelError.assertError()
        }
        #else
        let newHandle = openat(unsafeRawHandle, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard newHandle >= 0 else {
            try LowLevelError.assertError()
        }
        #endif

        // This new handle is completely independent of the original one, so we can safely send it
        nonisolated(unsafe) let reOpenHandle = UnsafeSystemHandle(owningRawHandle: newHandle)
        return reOpenHandle

    }

}
