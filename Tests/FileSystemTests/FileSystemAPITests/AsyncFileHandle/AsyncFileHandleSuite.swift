import Testing



/// Contract tests for the async handle family of `SwiftAsyncFileSystem`. The handles are made
/// of three kinds of code, tested three ways:
///
/// - thin shells: every initializer, `close()`, the executor-dispatched I/O primitives,
///   resize/synchronize and the metadata family forward to the synchronous implementation
///   through the executor (`SyncHandleView` runs the very same synchronous protocol
///   extensions). They get forwarding tests whose arguments carry non-default observable
///   values, plus pre-cancelled tests; the file semantics themselves stay pinned by the
///   synchronous `FileHandle` groups and are not re-tested;
/// - parallel implementations: the async positional accessor behind the sequential views,
///   `AsyncAppendHandle.append` and the async copies of the buffer convenience overloads have
///   their semantics rebuilt from the corresponding synchronous tests;
/// - behavior without a synchronous counterpart: cancellation, concurrent use, executor
///   routing and lifecycle are designed on their own.
///
/// NOTE: If a shell's implementation ever stops being "executor dispatch of the synchronous
/// call", rebuild its semantic coverage from the corresponding synchronous test group.
@Suite("AsyncFileHandle", .executionGroup(.default), .catchTestCancellation)
struct AsyncFileHandleAPITests {

    typealias Support = FileSystemTestSupport

}
