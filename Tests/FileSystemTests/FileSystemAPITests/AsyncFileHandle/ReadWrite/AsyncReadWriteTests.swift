import Foundation
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests {

    @Suite("ReadWrite")
    struct ReadWriteTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }


        func capturedContents(at path: FilePath) throws -> ByteBuffer {
            ByteBuffer(try Data(contentsOf: URL(filePath: path.string)))
        }

    }

}
