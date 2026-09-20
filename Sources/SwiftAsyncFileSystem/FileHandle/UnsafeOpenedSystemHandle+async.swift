import struct SwiftFileSystem.UnsafeHandleContextView
import struct FileSystemCore.UnsafeUnownedSystemHandle


extension UnsafeUnownedSystemHandle {

    @concurrent
    func unsafeTemporaryConvertingToOwning<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> R
    ) async throws(E) -> R {
        let tmpHandle = UnsafeSystemHandle(owningRawHandle: self.unsafeRawHandle)
        do {
            let r = try await operation(tmpHandle)
            _ = tmpHandle.take()
            return r
        } catch {
            _ = tmpHandle.take()
            throw error
        }
    }

}



extension UnsafeHandleContextView {

    @concurrent
    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(
        _ body: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> R
    ) async throws(E) -> R {
        try await unownedSystemHandle.unsafeTemporaryConvertingToOwning(body)
    }

}
