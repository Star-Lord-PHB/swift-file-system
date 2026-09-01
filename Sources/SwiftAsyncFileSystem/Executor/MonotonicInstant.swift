//
//  MonotonicInstant.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/8/24.
//

import PlatformCLib


/// A length of time between two ``MonotonicInstant`` values, stored as nanoseconds.
public struct MonotonicDuration: Sendable, Equatable, Hashable, Comparable {

    public let nanoseconds: Int64


    public static var zero: MonotonicDuration { .init(nanoseconds: 0) }

    public static func nanoseconds(_ amount: Int64) -> MonotonicDuration {
        return .init(nanoseconds: amount)
    }

    public static func microseconds(_ amount: Int64) -> MonotonicDuration {
        return .init(nanoseconds: amount * 1_000)
    }

    public static func milliseconds(_ amount: Int64) -> MonotonicDuration {
        return .init(nanoseconds: amount * 1_000_000)
    }

    public static func seconds(_ amount: Int64) -> MonotonicDuration {
        return .init(nanoseconds: amount * 1_000_000_000)
    }


    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.nanoseconds < rhs.nanoseconds
    }

}


/// A point on the platform's monotonic clock, immune to wall-clock adjustments. The epoch is
/// arbitrary (roughly boot time), so only differences between instants are meaningful.
///
/// `now()` must stay in the same timebase the timed condition-variable wait uses:
/// - Darwin: `CLOCK_UPTIME_RAW`, the mach timebase `pthread_cond_timedwait_relative_np`
///   measures its relative timeout against.
/// - Other POSIX: `CLOCK_MONOTONIC`, the clock ``ConditionalVariable`` binds via
///   `pthread_condattr_setclock`, so deadlines pass through as absolute times.
/// - Windows: `QueryPerformanceCounter`.
struct MonotonicInstant: Sendable, Equatable, Hashable, Comparable {

    /// Nanoseconds since the clock's arbitrary epoch.
    let rawNanoseconds: Int64


    static func now() -> MonotonicInstant {
        #if canImport(WinSDK)
        var counter = LARGE_INTEGER()
        QueryPerformanceCounter(&counter)
        let frequency = queryPerformanceFrequency
        // Split the conversion so ticks * 1e9 cannot overflow Int64.
        let seconds = counter.QuadPart / frequency
        let remainderTicks = counter.QuadPart % frequency
        return .init(rawNanoseconds: seconds * 1_000_000_000 + remainderTicks * 1_000_000_000 / frequency)
        #elseif canImport(Darwin)
        return .init(rawNanoseconds: Int64(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)))
        #else
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC, &time)
        return .init(rawNanoseconds: Int64(time.tv_sec) * 1_000_000_000 + Int64(time.tv_nsec))
        #endif
    }


    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawNanoseconds < rhs.rawNanoseconds
    }

    static func + (instant: MonotonicInstant, duration: MonotonicDuration) -> MonotonicInstant {
        return .init(rawNanoseconds: instant.rawNanoseconds + duration.nanoseconds)
    }

    static func - (end: MonotonicInstant, start: MonotonicInstant) -> MonotonicDuration {
        return .init(nanoseconds: end.rawNanoseconds - start.rawNanoseconds)
    }

}


#if canImport(WinSDK)
private let queryPerformanceFrequency: Int64 = {
    var frequency = LARGE_INTEGER()
    QueryPerformanceFrequency(&frequency)
    return frequency.QuadPart
}()
#endif
