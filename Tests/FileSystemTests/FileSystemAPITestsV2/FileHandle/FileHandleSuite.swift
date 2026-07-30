import Testing



@Suite("FileHandle", .catchTestCancellation)
struct FileHandleAPITests {

    typealias Support = FileSystemTestSupport

}
