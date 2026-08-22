import Testing

#if canImport(WinSDK)
    import WinSDK
#elseif canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

/// Process-wide resource counting for dedicated resource-lifetime tests.
///
/// Counts are affected by every concurrently running test in the process. Do
/// not use this helper in ordinary functional suites; it is reserved for the
/// serialized ResourceLifetime suite, which runs in its own process-exclusive
/// `TestExecutionGroup`.
extension FileSystemTestSupport {

    enum ProcessResourceLeakChecker {

        static func currentOpenResourceCount() throws -> Int64 {
            #if canImport(WinSDK)
                var count = DWORD(0)
                guard GetProcessHandleCount(GetCurrentProcess(), &count) else {
                    throw CountError.unableToReadOpenResourceCount
                }
                return Int64(count)

            #elseif canImport(Darwin)
                let byteCount = proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, nil, 0)
                guard byteCount >= 0 else {
                    throw CountError.unableToReadOpenResourceCount
                }
                return Int64(byteCount / Int32(MemoryLayout<proc_fdinfo>.size))

            #else
                guard let directory = opendir("/proc/self/fd") else {
                    throw CountError.unableToReadOpenResourceCount
                }
                defer { closedir(directory) }

                var count = Int64(0)
                while readdir(directory) != nil {
                    count += 1
                }
                // Exclude `.` and `..`. The directory descriptor remains part of both
                // the before and after samples and therefore does not affect the delta.
                return count - 2
            #endif
        }

        /// Verifies that `operation` does not leak process-wide fd/handle resources.
        ///
        /// The operation first runs once as a warm-up, so resources the OS or runtime lazily
        /// creates on first use exist before any sample is taken. Each measurement attempt then
        /// samples the count, runs the operation `iterations` times and samples again: a
        /// deterministic per-call leak inflates the delta by at least `iterations`, while
        /// unrelated background activity only shifts it by a few. A non-zero delta retries the
        /// whole measurement (up to `attempts`), so one-off OS activity between two samples does
        /// not fail the check, while a real leak fails every attempt.
        static func expectNoLeak(
            iterations: Int = 8,
            attempts: Int = 3,
            sourceLocation: SourceLocation = #_sourceLocation,
            operation: () throws -> Void
        ) throws {
            try operation()

            var deltas = [Int64]()
            repeat {
                let before = try currentOpenResourceCount()
                for _ in 0 ..< iterations {
                    try operation()
                }
                let after = try currentOpenResourceCount()
                guard after != before else { return }
                deltas.append(after - before)
            } while deltas.count < attempts

            #expect(
                Bool(false),
                """
                Open process resource count changed on every attempt; \
                deltas per \(iterations) iterations: \(deltas)
                """,
                sourceLocation: sourceLocation
            )
        }

    }

}

extension FileSystemTestSupport.ProcessResourceLeakChecker {

    enum CountError: Error {
        case unableToReadOpenResourceCount
    }

}
