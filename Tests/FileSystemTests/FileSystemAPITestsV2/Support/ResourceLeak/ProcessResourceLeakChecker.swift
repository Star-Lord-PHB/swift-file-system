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
/// not use this helper in ordinary functional suites; run its callers with
/// process-level isolation or with testing parallelism disabled.
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

        static func expectNoLeak<R>(
            sourceLocation: SourceLocation = #_sourceLocation,
            preheat: (() throws -> Void)? = nil,
            operation: () throws -> R
        ) throws -> R {
            try preheat?()
            let before = try currentOpenResourceCount()

            let result: Result<R, any Error>
            do {
                result = .success(try operation())
            } catch {
                result = .failure(error)
            }

            let after = try currentOpenResourceCount()
            expectCountsEqual(before, after, sourceLocation: sourceLocation)
            return try result.get()
        }

        static func expectNoLeak<R>(
            sourceLocation: SourceLocation = #_sourceLocation,
            preheat: (() async throws -> Void)? = nil,
            operation: () async throws -> R
        ) async throws -> R {
            try await preheat?()
            let before = try currentOpenResourceCount()

            let result: Result<R, any Error>
            do {
                result = .success(try await operation())
            } catch {
                result = .failure(error)
            }

            let after = try currentOpenResourceCount()
            expectCountsEqual(before, after, sourceLocation: sourceLocation)
            return try result.get()
        }

        private static func expectCountsEqual(
            _ before: Int64,
            _ after: Int64,
            sourceLocation: SourceLocation
        ) {
            #expect(
                before == after,
                "Open process resource count changed from \(before) to \(after)",
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
