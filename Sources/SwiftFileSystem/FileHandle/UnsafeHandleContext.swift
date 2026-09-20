import struct FileSystemCore.UnsafeSystemHandle



package struct UnsafeHandleContext: ~Copyable {

    package let systemHandle: UnsafeSystemHandle
    package let openOptions: UnsafeSystemHandle.OpenOptions?

    package var view: UnsafeHandleContextView {
        @_lifetime(borrow self)
        get {
            .init(handle: systemHandle, openOptions: openOptions)
        }
    }


    package init(
        handle: consuming UnsafeSystemHandle,
        openOptions: UnsafeSystemHandle.OpenOptions? = nil
    ) {
        self.systemHandle = handle
        self.openOptions = openOptions
    }


    package func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ body: (borrowing UnsafeSystemHandle) throws(E) -> R
    ) throws(E) -> R {
        try body(systemHandle)
    }


    package func withUnsafeMetadataHandle<R: ~Copyable>(
        requiringAccess metadataAccess: FileOperationOptions.MetadataHandleAccess,
        _ body: (borrowing UnsafeSystemHandle) throws(LowLevelError) -> R
    ) throws(LowLevelError) -> R {
        try view.withUnsafeMetadataHandle(requiringAccess: metadataAccess, body)
    }


    package consuming func close() throws(LowLevelError) {
        try systemHandle.close()
    }

}



extension UnsafeHandleContext {

    // The shared open path of the three streaming handles. They connect to an existing endpoint
    // and never wait for a peer: POSIX opens with O_NONBLOCK so a FIFO open cannot block and
    // restores blocking mode right after for the actual I/O; a Windows CreateFile never waits for
    // a peer on its own (a named-pipe client fails fast when no instance is available). O_NOCTTY
    // keeps an opened terminal from becoming the controlling terminal as a side effect.

    static func openForStreaming(
        at path: FilePath,
        access: UnsafeSystemHandle.OpenOptions.AccessMode,
        options: FileOperationOptions.OpenForStreaming
    ) throws(PlatformError) -> UnsafeHandleContext {
        
        let openOptions = UnsafeSystemHandle.OpenOptions(
            access: access,
            noFollow: options.noFollow,
            closeOnExec: options.closeOnExec,
            platformOpenFlagsDiff: .inserted([.posix.nonBlocking, .posix.noCtty])
        )

        let handle = try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try UnsafeSystemHandle.open(at: path, openOptions: openOptions)
        } kindConversion: { error in
            switch error.systemCode {
                #if canImport(WinSDK)
                case .accessDenied: .windows.permissionDeniedOrIsADirectory
                case .pipeBusy: .peerUnavailable
                #else
                case .noSuchDeviceOrAddress: .peerUnavailable
                #endif
                default: error.kind
            }
        }

        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            switch try handle.type() {
                case .symlink: throw .init(kind: .pathResolutionFailed)
                case .directory: throw .init(kind: .isADirectory)
                default: break
            }
        }

        #if !canImport(WinSDK)
        try catchLowLevelError(operation: .open(path)) { () throws(LowLevelError) in
            try handle.setNonBlocking(false)
            #if canImport(Darwin) || os(FreeBSD)
            // A torn-down peer should surface as a brokenPipe error instead of raising
            // SIGPIPE; Linux and OpenBSD have no per-descriptor equivalent, so there the
            // process itself has to deal with SIGPIPE.
            try handle.withUnsafeRawHandle { fd throws(LowLevelError) in
                try execThrowingCFunction {
                    fcntl(fd, F_SETNOSIGPIPE, 1)
                }
            }
            #endif
        }
        #endif

        return .init(handle: handle, openOptions: openOptions)

    }

}



public struct UnsafeHandleContextView: ~Escapable {

    // Lends the unowned raw handle as an `UnsafeSystemHandle` without ever closing it. The temporary owning
    // handle lives in a box whose deinit consumes it through `take()`: when the caller throws while a `_read`
    // access is active, the coroutine is aborted and the code after `yield` never runs, but the locals alive
    // at the yield are still destroyed, so the box's deinit is the one cleanup that runs on both paths.
    private struct NonClosingHandleBox: ~Copyable {
        let handle: UnsafeSystemHandle
        init(_ handle: consuming UnsafeSystemHandle) {
            self.handle = handle
        }
        deinit {
            _ = handle.take()
        }
    }

    package let unownedSystemHandle: UnsafeUnownedSystemHandle
    public let openOptions: UnsafeSystemHandle.OpenOptions?

    public var systemHandle: UnsafeSystemHandle {
        _read {
            let box = NonClosingHandleBox(.init(owningRawHandle: unownedSystemHandle.unsafeRawHandle))
            yield box.handle
        }
    }


    @_lifetime(copy handle)
    package init(
        handle: UnsafeUnownedSystemHandle,
        openOptions: UnsafeSystemHandle.OpenOptions? = nil
    ) {
        self.unownedSystemHandle = handle
        self.openOptions = openOptions
    }


    @_lifetime(borrow handle)
    public init(
        handle: borrowing UnsafeSystemHandle,
        openOptions: UnsafeSystemHandle.OpenOptions? = nil
    ) {
        self.unownedSystemHandle = handle.unownedHandle()
        self.openOptions = openOptions
    }


    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ body: (borrowing UnsafeSystemHandle) throws(E) -> R
    ) throws(E) -> R {
        try unownedSystemHandle.unsafeTemporaryConvertingToOwning(body)
    }


    public func withUnsafeMetadataHandle<R: ~Copyable>(
        requiringAccess metadataAccess: FileOperationOptions.MetadataHandleAccess,
        _ body: (borrowing UnsafeSystemHandle) throws(LowLevelError) -> R
    ) throws(LowLevelError) -> R {

        #if canImport(WinSDK)

        let windowsAccess = self.openOptions?.estimatedMappedWindowsAccess ?? []

        if windowsAccess.isSuperset(of: metadataAccess.accessMask) {
            return try unownedSystemHandle.unsafeTemporaryConvertingToOwning(body)
        }

        let newHandle = try unownedSystemHandle.reOpen(withAccess: metadataAccess.accessMask)
        return try body(newHandle)

        #else

        return try unownedSystemHandle.unsafeTemporaryConvertingToOwning(body)

        #endif

    }

}



extension UnsafeHandleContextView {

    package static func trySeek(from offset: Int64, by amount: Int64) throws(LowLevelError) -> Int64 {
        let (result, overflow) = offset.addingReportingOverflow(amount)
        if overflow {
            throw .init(kind: .arithmeticOverflow)
        } else if result < 0 {
            throw .init(kind: .invalidInput)
        }
        return result
    }

}
