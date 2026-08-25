import Foundation
import Testing
import SwiftAsyncFileSystem


@Suite("AsyncFileSystemExecutor", .executionGroup(.default), .catchTestCancellation)
struct AsyncFileSystemExecutorTests {}



extension AsyncFileSystemExecutorTests {

    /// Independent read-back oracle for thread names. This file imports SwiftAsyncFileSystem
    /// without `@testable`, so the module's internal `Thread` stays invisible and `Thread`
    /// here is unambiguously Foundation's.
    ///
    /// For the current thread, Foundation reads the name from the same OS state the library's
    /// setter writes: Darwin's NSThread reads the pthread name, and swift-corelibs-foundation
    /// goes through `_CFThreadGetName` (`pthread_getname_np` on Linux, `GetThreadDescription`
    /// on Windows).
    static func foundationCurrentThreadName() -> String? {
        return Thread.current.name
    }


    final class SharedBox<Value>: @unchecked Sendable {

        var value: Value

        init(_ value: Value) {
            self.value = value
        }

    }

}
