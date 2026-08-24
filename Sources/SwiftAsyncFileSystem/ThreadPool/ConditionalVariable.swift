//
//  ConditionalVariable.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/23.
//

import PlatformCLib


/// A mutex + condition variable pair (NSCondition-style): `lock`/`unlock` guard the shared
/// state, and `wait()` atomically releases the lock and sleeps until signaled.
///
/// - `wait()` must be called with the lock held, and only inside a loop that re-checks the
///   predicate: spurious wakeups are possible on every platform.
/// - `signal()`/`broadcast()` may be called with or without the lock held.
final class ConditionalVariable: @unchecked Sendable {

    // Deliberately heap-allocated: these objects queue waiters on their own address, so the
    // storage must stay address-stable and must never be copied. Storing them as plain
    // properties and passing `&property` guarantees neither — the inout bridging may pass a
    // temporary copy, and it counts as an exclusive access for the whole call, so concurrent
    // lock/wait/signal calls would overlap and trap under exclusivity enforcement.
    #if canImport(WinSDK)
    private let lockStorage: UnsafeMutablePointer<SRWLOCK>
    private let conditionStorage: UnsafeMutablePointer<CONDITION_VARIABLE>
    #else
    private let lockStorage: UnsafeMutablePointer<pthread_mutex_t>
    private let conditionStorage: UnsafeMutablePointer<pthread_cond_t>
    #endif


    init() {
        lockStorage = .allocate(capacity: 1)
        conditionStorage = .allocate(capacity: 1)

        #if canImport(WinSDK)
        InitializeSRWLock(lockStorage)
        InitializeConditionVariable(conditionStorage)
        #else
        let mutexCode = pthread_mutex_init(lockStorage, nil)
        precondition(mutexCode == 0, "pthread_mutex_init failed with error \(mutexCode)")
        let conditionCode = pthread_cond_init(conditionStorage, nil)
        precondition(conditionCode == 0, "pthread_cond_init failed with error \(conditionCode)")
        #endif
    }


    deinit {
        // SRWLOCK / CONDITION_VARIABLE have no destroy API; only the pthread objects do.
        #if !canImport(WinSDK)
        let conditionCode = pthread_cond_destroy(conditionStorage)
        precondition(conditionCode == 0, "pthread_cond_destroy failed with error \(conditionCode)")
        let mutexCode = pthread_mutex_destroy(lockStorage)
        precondition(mutexCode == 0, "pthread_mutex_destroy failed with error \(mutexCode)")
        #endif

        conditionStorage.deallocate()
        lockStorage.deallocate()
    }


    func lock() {
        #if canImport(WinSDK)
        AcquireSRWLockExclusive(lockStorage)
        #else
        let code = pthread_mutex_lock(lockStorage)
        precondition(code == 0, "pthread_mutex_lock failed with error \(code)")
        #endif
    }


    func unlock() {
        #if canImport(WinSDK)
        ReleaseSRWLockExclusive(lockStorage)
        #else
        let code = pthread_mutex_unlock(lockStorage)
        precondition(code == 0, "pthread_mutex_unlock failed with error \(code)")
        #endif
    }


    /// Atomically releases the lock and blocks until signaled, then reacquires the lock
    /// before returning. The caller must hold the lock.
    func wait() {
        #if canImport(WinSDK)
        let result = SleepConditionVariableSRW(conditionStorage, lockStorage, INFINITE, 0)
        precondition(result, "SleepConditionVariableSRW failed with error \(GetLastError())")
        #else
        let code = pthread_cond_wait(conditionStorage, lockStorage)
        precondition(code == 0, "pthread_cond_wait failed with error \(code)")
        #endif
    }


    /// Wakes at least one waiting thread, if any.
    func signal() {
        #if canImport(WinSDK)
        WakeConditionVariable(conditionStorage)
        #else
        let code = pthread_cond_signal(conditionStorage)
        precondition(code == 0, "pthread_cond_signal failed with error \(code)")
        #endif
    }


    /// Wakes every waiting thread.
    func broadcast() {
        #if canImport(WinSDK)
        WakeAllConditionVariable(conditionStorage)
        #else
        let code = pthread_cond_broadcast(conditionStorage)
        precondition(code == 0, "pthread_cond_broadcast failed with error \(code)")
        #endif
    }


    /// Runs `body` with the lock held. Calling `wait()` inside `body` is valid — it releases
    /// the lock while sleeping and reacquires it before returning, so the balancing `unlock()`
    /// still sees the lock held. Nesting `withLock` on the same instance deadlocks: the
    /// underlying lock is not recursive.
    func withLock<Result: ~Copyable, Failure: Error>(
        _ body: () throws(Failure) -> Result
    ) throws(Failure) -> Result {
        lock()
        defer { unlock() }
        return try body()
    }

}
