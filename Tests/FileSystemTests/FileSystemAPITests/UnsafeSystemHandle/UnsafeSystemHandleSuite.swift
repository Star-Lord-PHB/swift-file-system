import Testing



@Suite("UnsafeSystemHandle", .executionGroup(.default), .catchTestCancellation)
struct UnsafeSystemHandleAPITests {

    typealias Support = FileSystemTestSupport

}
