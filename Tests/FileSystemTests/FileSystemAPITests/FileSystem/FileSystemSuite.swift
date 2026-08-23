import Testing



@Suite("FileSystem", .executionGroup(.default), .catchTestCancellation)
struct FileSystemAPITests {

    typealias Support = FileSystemTestSupport

}
