//
//  CancellationToken.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/28.
//

import PlatformCLib


/// A one-shot cancellation flag bridging Swift task cancellation onto executor worker
/// threads: `withTaskCancellationHandler` sets it from task context, and workers poll it
/// before starting a queued job. Workers run outside any Swift task, where
/// `Task.isCancelled` is always false, so cancellation must travel through shared state
/// like this instead.
///
/// Setting is irreversible, and both operations are safe from any thread.
struct CancellationToken: ~Copyable, @unchecked Sendable {

    // Deliberately heap-allocated for a stable address: atomic operations must all target
    // the one true storage location, while `&property` inout bridging may pass a temporary
    // copy and counts as an exclusive access for the whole call, so concurrent
    // cancel/isCancelled calls would overlap and trap under exclusivity enforcement.
    private let flag: UnsafeMutablePointer<CFSAtomicFlag>


    init() {
        flag = .allocate(capacity: 1)
        flag.initialize(to: .init())
        cfsAtomicFlagInitialize(flag)
    }


    deinit {
        flag.deinitialize(count: 1)
        flag.deallocate()
    }


    func cancel() {
        cfsAtomicFlagSet(flag)
    }


    var isCancelled: Bool {
        cfsAtomicFlagIsSet(flag)
    }

}
