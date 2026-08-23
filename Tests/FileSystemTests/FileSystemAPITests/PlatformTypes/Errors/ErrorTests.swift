import Testing
import SwiftFileSystem



extension PlatformTypesAPITests {

    @Suite("Errors")
    struct ErrorTests {}

}



// Helpers shared by more than one error suite.
extension PlatformTypesAPITests.ErrorTests {

    /// A native code whose default mapping is `.notFound`, so that cross-platform tests can
    /// exercise the code-carrying paths without naming a platform code themselves.
    static var notFoundCode: SystemErrorCode {
        #if canImport(WinSDK)
        .fileNotFound
        #else
        .noSuchFileOrDirectory
        #endif
    }

}
