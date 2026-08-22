import Testing


/// Process-wide resource-leak coverage for APIs whose internal fds/handles are invisible to
/// callers: path-based queries and operations, enumeration, and opens that acquire a handle
/// and then reject the item. Handles that are returned to the caller are covered by the
/// FileHandle Lifecycle, UnsafeSystemHandle Lifecycle and Handles groups via
/// `SystemHandleProbe` and are not re-tested here.
///
/// The suite counts fds/handles of the whole process, so it must never run alongside other
/// tests: it belongs to the `resourceLifetime` execution group
/// (`TEST_EXECUTION_GROUP=resourceLifetime`) and is serialized within that group.
@Suite(
    "ResourceLifetime",
    .serialized,
    .executionGroup(.resourceLifetime),
    .catchTestCancellation
)
struct ResourceLifetimeTests {

    typealias Support = FileSystemTestSupport

    typealias LeakChecker = Support.ProcessResourceLeakChecker

}
