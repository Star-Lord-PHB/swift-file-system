import Foundation
import Testing


@Suite("ThreadPool", .executionGroup(.default), .catchTestCancellation)
struct ThreadPoolTests {}



extension ThreadPoolTests {

    /// Independent read-back oracle for thread names. This file imports Foundation but not
    /// SwiftAsyncFileSystem, so `Thread` here is unambiguously Foundation's.
    ///
    /// For the current thread, Foundation reads the name from the same OS state the library's
    /// setter writes: Darwin's NSThread reads the pthread name, and swift-corelibs-foundation
    /// goes through `_CFThreadGetName` (`pthread_getname_np` on Linux, `GetThreadDescription`
    /// on Windows).
    static func foundationCurrentThreadName() -> String? {
        return Thread.current.name
    }

}
