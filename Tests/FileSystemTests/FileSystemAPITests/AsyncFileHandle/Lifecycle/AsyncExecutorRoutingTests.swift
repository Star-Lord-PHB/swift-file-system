import Foundation
import Testing
import SwiftAsyncFileSystem



// NOTE: `withUnsafeSystemHandleInExecutor` is the one public entry that runs a caller closure
// on the handle's executor, so it is the observation point for "the handle's work is
// dispatched to the executor it was opened with": a single persistent pool thread carries the
// label in its name, read back through Foundation as in the executor tests. The views reach
// the executor through the positional accessor, hence their own case.
// FreeBSD/OpenBSD skip thread naming, so the tests are omitted there.
#if !os(FreeBSD) && !os(OpenBSD)
extension AsyncFileHandleAPITests.LifecycleTests {

    @Test(.timeLimit(.minutes(1)))
    func `Handle work runs on the executor it was opened with`() async throws {

        let path = try workspace.makeFile(at: "file")
        let executor = AsyncFileSystemExecutor(label: "route", threadCount: 1)
        let handle = try await AsyncReadFileHandle(forFileAt: path, executor: executor)

        let threadName = try await handle.withUnsafeSystemHandleInExecutor { _ in
            Thread.current.name
        }.get()

        #expect(threadName == "route-0")

        try await handle.close()

    }


    @Test(.timeLimit(.minutes(1)))
    func `View work runs on the executor its handle was opened with`() async throws {

        let path = try workspace.makeFile(at: "file")
        let executor = AsyncFileSystemExecutor(label: "vroute", threadCount: 1)
        let handle = try await AsyncReadFileHandle(forFileAt: path, executor: executor)
        let reader = handle.sequentialReader()

        let threadName = try await reader.withUnsafeSystemHandleInExecutor { _ in
            Thread.current.name
        }.get()

        #expect(threadName == "vroute-0")

    }


    @Test(.timeLimit(.minutes(1)))
    func `Directory handle work runs on the executor it was opened with`() async throws {

        let path = try workspace.makeDirectory(at: "directory")
        let executor = AsyncFileSystemExecutor(label: "droute", threadCount: 1)
        let handle = try await AsyncDirectoryHandle(forDirAt: path, executor: executor)

        let threadName = try await handle.withUnsafeSystemHandleInExecutor { _ in
            Thread.current.name
        }.get()

        #expect(threadName == "droute-0")

        try await handle.close()

    }

}
#endif
