import Testing
import SwiftAsyncFileSystem


/// Contract tests for `AsyncFileSystem`, whose methods are thin shells dispatching the fully
/// tested synchronous `FileSystem` through `AsyncFileSystemExecutor.runCancellable`. The
/// exceptions: `itemExists` goes through the non-cancellable `run` instead, while `copyItem`
/// and `removeItem` drive their sessions in time slices themselves and have their own groups,
/// `CopyTests` and `RemovalTests`.
/// File-system semantics are deliberately not re-tested here; the synchronous test groups
/// remain their single source of truth. Each async method gets:
///
/// - a forwarding test: parameters carry non-default observable values, so a dropped or
///   swapped argument in the shell changes the asserted outcome. The follow-symlink flags
///   share one forwarding expression shape across the metadata family, so they are
///   discriminated on representatives (`itemExists`, `info`) rather than per method.
/// - a pre-cancelled test: the method observes Swift task cancellation before doing any
///   work and surfaces the standard cancellation error, per the `AsyncFileSystemProtocol`
///   contract (`itemExists`, which cannot report cancellation, is shown to still answer).
///
/// The cancellation mechanics themselves (two checkpoints, lazy error construction, a
/// started body always running to completion) are pinned by `AsyncFileSystemExecutorTests`
/// and not repeated. The wrapper sources are platform-shared except where `#if` carves them
/// up (POSIX permissions, Linux inode flags, Windows security), so each distinct wrapper
/// source is proven once and the platform-specific shells get their own suites.
///
/// NOTE: If a method's implementation ever stops being `runCancellable { synchronous
/// call }`, these contract tests stop covering it — rebuild its semantic coverage from the
/// corresponding synchronous test group.
@Suite("AsyncFileSystem", .executionGroup(.default), .catchTestCancellation)
struct AsyncFileSystemAPITests {

    typealias Support = FileSystemTestSupport

}
