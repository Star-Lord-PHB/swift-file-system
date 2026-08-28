import Foundation
import Testing
import SwiftFileSystem



extension FileHandleAPITests {

    @Suite("StreamingReadWrite")
    struct StreamingReadWriteTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }


        func capturedContents(at path: FilePath) throws -> ByteBuffer {
            ByteBuffer(try Data(contentsOf: URL(filePath: path.string)))
        }

    }

}
