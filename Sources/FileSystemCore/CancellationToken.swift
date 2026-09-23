//
//  CancellationToken.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/28.
//

import PlatformCLib


/// A one-shot thread-safe cancellation flag use for indicating cancellation outside Swift Concurrency
/// 
/// Set the flag to `cancelled` by calling `cancel()` method and check the cancellation status by reading 
/// the `isCancelled` property.
package final class CancellationToken: @unchecked Sendable {

    // Deliberately heap-allocated for a stable address: atomic operations must all target
    // the one true storage location
    private let flag: UnsafeMutablePointer<CFSAtomicFlag>

    package var unsafeFlagPtr: UnsafeUnownedMutablePointer<CFSAtomicFlag> {
        @_lifetime(borrow self)
        get {
            .init(unownedPointer: flag)
        }
    }


    package init() {
        flag = .allocate(capacity: 1)
        flag.initialize(to: .init())
        cfsAtomicFlagInitialize(flag)
    }


    deinit {
        flag.deinitialize(count: 1)
        flag.deallocate()
    }


    package func cancel() {
        cfsAtomicFlagSet(flag)
    }


    package var isCancelled: Bool {
        cfsAtomicFlagIsSet(flag)
    }

}
