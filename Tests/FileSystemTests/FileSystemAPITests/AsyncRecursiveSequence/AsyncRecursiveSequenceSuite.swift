import Testing



/// Contract tests for `AsyncDirectoryEntryRecursiveSequence`. The sequence wraps the synchronous
/// path-based traversal: its iterator drives the synchronous iterator on the executor in
/// batches, so what is pinned here is the batching engine (element order across batch
/// boundaries, root errors thrown once, cancellation) and the convenience methods written on the
/// concrete type. The traversal semantics themselves stay covered by the synchronous
/// `RecursiveSequence` group.
@Suite("AsyncRecursiveSequence", .executionGroup(.default), .catchTestCancellation)
struct AsyncRecursiveSequenceAPITests {

    typealias Support = FileSystemTestSupport

}
