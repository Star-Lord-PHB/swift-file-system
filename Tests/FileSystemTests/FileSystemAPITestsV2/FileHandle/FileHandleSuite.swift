import Testing



@Suite("FileHandle", .executionGroup(.default), .catchTestCancellation)
struct FileHandleAPITests {

    typealias Support = FileSystemTestSupport

}
