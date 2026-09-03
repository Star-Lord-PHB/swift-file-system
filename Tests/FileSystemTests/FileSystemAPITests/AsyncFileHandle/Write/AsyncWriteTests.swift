import Foundation
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests {

    @Suite("Write")
    struct WriteTests {

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
