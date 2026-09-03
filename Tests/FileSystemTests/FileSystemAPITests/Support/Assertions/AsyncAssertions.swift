import Testing
import FileSystemCore



extension FileSystemTestSupport {

    /// Runs `body` inside a task that is already cancelled when the operation is entered and
    /// expects the standard library-level cancellation error.
    ///
    /// The closure is `sending` so it can capture a non-Sendable handle opened by the test;
    /// the capture moves the handle into the task, so the test cannot use it afterwards.
    static func expectPreCancelled<R: Sendable>(
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: sending @escaping @isolated(any) () async throws -> R
    ) async {
        let task = Task {
            // Guarantee the cancellation is observable before the operation is entered, so
            // the pre-submit checkpoint deterministically fires.
            while !Task.isCancelled { await Task.yield() }
            return try await body()
        }
        task.cancel()

        let error = await #expect(throws: PlatformError.self, sourceLocation: sourceLocation) {
            try await task.value
        }
        expectStandardCancellation(error, sourceLocation: sourceLocation)
    }


    /// Runs `body` inside a task that is already cancelled when it is entered, for tests that
    /// assert next to the operation (such as on a view cursor, which only exists inside the
    /// task); expectations made inside the body are recorded against the current test.
    static func runPreCancelled<R: Sendable>(
        _ body: sending @escaping @isolated(any) () async -> R
    ) async -> R {
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            return await body()
        }
        task.cancel()
        return await task.value
    }


    /// The standard library-level cancellation error: kind `.cancelled`, no system code and a
    /// `CancellationError` underneath.
    static func expectStandardCancellation(
        _ error: PlatformError?,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(error?.kind == .cancelled, sourceLocation: sourceLocation)
        #expect(error?.systemCode == nil, sourceLocation: sourceLocation)
        #expect(error?.underlyingError is CancellationError, sourceLocation: sourceLocation)
    }

}
