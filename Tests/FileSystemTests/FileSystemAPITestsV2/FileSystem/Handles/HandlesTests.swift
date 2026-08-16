import Foundation
import SystemPackage
import Testing
import SwiftFileSystem



extension FileSystemAPITests {

    /// Tests for the scoped handle wrappers in `FileSystem+Handles`.
    ///
    /// The wrappers open a handle, run the body, and close the handle again. Handle
    /// behaviour itself is covered by the `FileHandle` suites, so these tests only pin
    /// the wrapping contract: the open error is propagated, the body result is returned,
    /// the body error is rethrown unchanged, and the underlying system handle is released
    /// on both paths.
    ///
    /// NOTE: the `try? handle.close()` in the rethrow path is deliberately untested.
    /// Forcing that `close()` to fail requires closing the raw descriptor from inside the
    /// body, and the freed descriptor number can be reused by a concurrently running test
    /// before the wrapper closes it again — the wrapper would then close an unrelated
    /// descriptor. The same applies to the `try handle.close()` on the success path.
    @Suite("Handles")
    struct HandlesTests {

        typealias Support = FileSystemAPITests.Support

        let fileSystem = FileSystem()
        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.HandlesTests {

    /// An error only the body can throw, so a test can tell it apart from any error the
    /// wrapper itself might produce.
    struct BodyError: Error, Equatable {
        let marker = "body error"
    }


    /// A non-copyable body result, used to pin that the wrappers accept a `~Copyable`
    /// return type.
    struct NonCopyableResult: ~Copyable {
        let contents: ByteBuffer
    }


    func capturedContents(at path: FilePath) throws -> ByteBuffer {
        ByteBuffer(try Data(contentsOf: URL(filePath: path.string)))
    }

}
