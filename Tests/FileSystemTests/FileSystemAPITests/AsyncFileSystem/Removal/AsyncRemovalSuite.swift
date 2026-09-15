import Testing
import SwiftAsyncFileSystem



extension AsyncFileSystemAPITests {

    /// Contract tests for `AsyncFileSystem.removeItem`. Like `copyItem` it is a driver rather than
    /// a thin shell: it steps the package-level `RecursiveRemoveItemHandler` on the executor in
    /// time slices, bridges Swift task cancellation onto the handler's token and throws the
    /// session's first error once the session completes. What gets removed and which error is
    /// reported for what comes from the handler and stays pinned by the synchronous
    /// `FileSystemAPITests.RemovalTests`; these tests only cover what the driver adds:
    ///
    /// - forwarding: the root reaches the handler, a removal spread over several time slices still
    ///   removes everything, and the session's error comes back thrown;
    /// - pre-cancellation: a task that is already cancelled gets the standard cancellation error
    ///   without a handler being run.
    ///
    /// Cancellation arriving while a removal is in progress depends on timing between tasks and is
    /// exercised by hand rather than here.
    @Suite("Removal")
    struct RemovalTests {}

}
