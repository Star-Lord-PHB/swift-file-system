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
/// - `wait()` and `wait(until:)` must be called with the lock held, and only inside a loop
///   that re-checks the predicate: spurious wakeups are possible on every platform.
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

        #if canImport(Darwin)
        // Darwin has no pthread_condattr_setclock; wait(until:) compensates by waiting with
        // the relative pthread_cond_timedwait_relative_np instead of an absolute deadline.
        let conditionCode = pthread_cond_init(conditionStorage, nil)
        #else
        // Bind the condvar to CLOCK_MONOTONIC — the clock MonotonicInstant reads — so timed
        // waits take deadlines as absolute times and are immune to wall-clock adjustments.
        var conditionAttributes = pthread_condattr_t()
        let attributesCode = pthread_condattr_init(&conditionAttributes)
        precondition(attributesCode == 0, "pthread_condattr_init failed with error \(attributesCode)")
        let clockCode = pthread_condattr_setclock(&conditionAttributes, CLOCK_MONOTONIC)
        precondition(clockCode == 0, "pthread_condattr_setclock failed with error \(clockCode)")
        let conditionCode = pthread_cond_init(conditionStorage, &conditionAttributes)
        pthread_condattr_destroy(&conditionAttributes)
        #endif

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


    /// Atomically releases the lock and blocks until signaled or until `deadline` passes,
    /// then reacquires the lock before returning. The caller must hold the lock.
    ///
    /// Returns `false` when the deadline passed and `true` when woken up (spurious wakeups
    /// included). Either way the caller re-checks its predicate: a `false` return says
    /// nothing about the predicate, and a `true` return does not guarantee progress.
    func wait(until deadline: MonotonicInstant) -> Bool {
        #if canImport(WinSDK)
        // SleepConditionVariableSRW only takes relative milliseconds, so the deadline cannot
        // pass through absolutely: loop and re-wait the remainder whenever a timeout fires
        // before the actual deadline (a scheduler tick can end waits early, and waits longer
        // than the DWORD range get clamped below INFINITE, which would sleep forever). The
        // millisecond conversion rounds up, clamping before the round-up so it cannot
        // overflow.
        while true {
            let remaining = deadline - .now()
            guard remaining > .zero else { return false }
            let cappedNanoseconds = min(remaining.nanoseconds, 0xFFFF_FFFE * 1_000_000)
            let milliseconds = DWORD((cappedNanoseconds + 999_999) / 1_000_000)
            let result = SleepConditionVariableSRW(conditionStorage, lockStorage, milliseconds, 0)
            if result { return true }
            let code = GetLastError()
            precondition(code == ERROR_TIMEOUT, "SleepConditionVariableSRW failed with error \(code)")
        }
        #else
        let remaining = deadline - .now()
        guard remaining > .zero else { return false }

        #if canImport(Darwin)
        var timeout = timespec(
            tv_sec: Int(remaining.nanoseconds / 1_000_000_000),
            tv_nsec: Int(remaining.nanoseconds % 1_000_000_000)
        )
        let code = pthread_cond_timedwait_relative_np(conditionStorage, lockStorage, &timeout)
        precondition(code == 0 || code == ETIMEDOUT, "pthread_cond_timedwait_relative_np failed with error \(code)")
        return code == 0
        #else
        // The condvar is bound to CLOCK_MONOTONIC (see init), the clock MonotonicInstant
        // reads, so the deadline passes through absolutely and re-waits never reset it.
        var absoluteDeadline = timespec(
            tv_sec: time_t(deadline.rawNanoseconds / 1_000_000_000),
            tv_nsec: Int(deadline.rawNanoseconds % 1_000_000_000)
        )
        let code = pthread_cond_timedwait(conditionStorage, lockStorage, &absoluteDeadline)
        precondition(code == 0 || code == ETIMEDOUT, "pthread_cond_timedwait failed with error \(code)")
        return code == 0
        #endif
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
