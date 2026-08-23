import Testing



@Suite("DirectorySequence", .executionGroup(.default), .catchTestCancellation)
struct DirectorySequenceAPITests {

    typealias Support = FileSystemTestSupport

}
