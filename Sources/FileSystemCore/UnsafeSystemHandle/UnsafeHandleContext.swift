import PlatformCLib



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



/// An unowned view of a ``UnsafeSystemHandle`` with its open options if available.
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
    /// The options used to open this ``UnsafeSystemHandle`` if available.
    public let openOptions: UnsafeSystemHandle.OpenOptions?

    /// Gets the ``UnsafeSystemHandle`` itself.
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


    /// Access the underlying ``UnsafeSystemHandle`` in a closure.
    /// - Parameter body: A closure for accessing the ``UnsafeSystemHandle``.
    public func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ body: (borrowing UnsafeSystemHandle) throws(E) -> R
    ) throws(E) -> R {
        try unownedSystemHandle.unsafeTemporaryConvertingToOwning(body)
    }


    /// Access a potentially re-opened ``UnsafeSystemHandle`` with the required metadata access permissions
    /// in a closure.
    /// - Parameters:
    ///   - metadataAccess: The required metadata access permissions granted to the handle.
    ///   - body: A closure for accessing the ``UnsafeSystemHandle``.
    /// 
    /// On Posix, the handle is never re-opened since a simple read-only handle is already capable of 
    /// accessing metadata. However, on Windows, access permissions for metadata must be explicitly requested, so 
    /// a handle may not have all the required access. In that case, the handle will be re-opened with the
    /// required access requested.
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
