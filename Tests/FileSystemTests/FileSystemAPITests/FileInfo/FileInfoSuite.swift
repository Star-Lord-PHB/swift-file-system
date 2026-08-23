import Testing



@Suite("FileInfo", .executionGroup(.default), .catchTestCancellation)
struct FileInfoAPITests {

    typealias Support = FileSystemTestSupport

}
