//
//  UnsafeUnownedSystemHandle+AsyncOwningConversion.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/9/2.
//

import FileSystemCore


extension UnsafeUnownedSystemHandle {

    @concurrent
    func unsafeTemporaryConvertingToOwning<R: ~Copyable, E: Error>(
        _ operation: @concurrent (borrowing UnsafeSystemHandle) async throws(E) -> sending R
    ) async throws(E) -> sending R {
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
