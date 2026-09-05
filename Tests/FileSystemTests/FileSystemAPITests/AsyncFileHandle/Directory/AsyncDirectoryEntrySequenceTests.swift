import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.DirectoryTests {

    @Suite("Entry sequence")
    struct EntrySequenceTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: The async iterator fetches entries from the synchronous iterator in batches on the
// executor and serves them from a buffer, checking task cancellation before touching the
// buffer. A handle an entry sequence was derived from cannot be consumed in the same scope
// afterwards, so these tests leave the release to deinit.
extension AsyncFileHandleAPITests.DirectoryTests.EntrySequenceTests {

    private func entry(
        _ path: FilePath,
        type: FileKind,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> DirectoryEntry {
        try #require(
            DirectoryEntry(path: path, type: type),
            sourceLocation: sourceLocation
        )
    }


    private func expectEntries(
        _ entries: [DirectoryEntry],
        match expected: Set<DirectoryEntry>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(entries.count == expected.count, sourceLocation: sourceLocation)
        #expect(Set(entries) == expected, sourceLocation: sourceLocation)
    }


    private func makeFiles(_ names: [String]) throws -> FilePath {
        var tree = [FilePath.Component: Support.Fixture]()
        for name in names {
            tree[try #require(FilePath.Component(name))] = .file(contents: name)
        }
        return try workspace.makeFixture(at: "directory", .directory(tree))
    }


    @Test
    func `Enumerates immediate children`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ]
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        let sequence = handle.entrySequence()
        let entries = try await sequence.map { $0 }

        expectEntries(
            entries,
            match: [
                try entry("file", type: .regular),
                try entry("subdir", type: .directory)
            ]
        )

    }


    @Test
    func `Forwards traversal options`() async throws {

        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [:],
                "dir-link": .symlink(target: "subdir")
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        let sequence = handle.entrySequence(options: .skipDir)
        let entries = try await sequence.map { $0 }

        expectEntries(
            entries,
            match: [
                try entry("file", type: .regular),
                try entry("dir-link", type: .symlink)
            ]
        )

    }


    // Batches smaller than, equal to and larger than the directory: the last fetch of every
    // variant is the one that observes the end of the synchronous iterator.
    @Test(arguments: [1, 2, 5, 128])
    func `Yields the same entries for any batch count`(batchCount: Int) async throws {

        let names = ["file-a", "file-b", "file-c", "file-d", "file-e"]
        let path = try makeFiles(names)
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        let sequence = handle.entrySequence(batchCount: batchCount)
        let entries = try await sequence.map { $0 }

        #expect(sequence.batchCount == batchCount)
        #expect(entries.count == names.count)
        #expect(Set(entries.map(\.name)) == Set(names))

    }


    @Test
    func `Ended reflects buffered entries`() async throws {

        let path = try makeFiles(["file-a", "file-b", "file-c"])
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence(batchCount: 128)
        var iterator = sequence.makeAsyncIterator()

        #expect(iterator.ended == false)
        #expect(iterator.rootPath == path)

        let first = try await iterator.next()
        #expect(first != nil)
        // The single batch already drained the synchronous iterator; two entries are still buffered.
        #expect(iterator.ended == false)

        var remainder = [DirectoryEntry]()
        while let entry = try await iterator.next() {
            remainder.append(entry)
        }

        #expect(remainder.count == 2)
        #expect(iterator.ended == true)
        #expect(try await iterator.next() == nil)

    }


    @Test
    func `Iterators of one sequence advance independently`() async throws {

        let names = ["file-a", "file-b", "file-c"]
        let path = try makeFiles(names)
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        var first = sequence.makeAsyncIterator()
        var second = sequence.makeAsyncIterator()

        let head = try await first.next()
        let headEntry = try #require(head)

        var secondEntries = [DirectoryEntry]()
        while let entry = try await second.next() {
            secondEntries.append(entry)
        }

        var firstRemainder = [DirectoryEntry]()
        while let entry = try await first.next() {
            firstRemainder.append(entry)
        }

        #expect(Set(secondEntries.map(\.name)) == Set(names))
        #expect(Set(([headEntry] + firstRemainder).map(\.name)) == Set(names))
        #expect(firstRemainder.count == names.count - 1)
        #expect(first.ended == true)
        #expect(second.ended == true)

    }


    @Test
    func `Can be iterated more than once`() async throws {

        let names = ["file-a", "file-b", "subdir"]
        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file-a": .file(contents: "a"),
                "file-b": .file(contents: "b"),
                "subdir": [:]
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        let sequence = handle.entrySequence()
        let first = try await sequence.map { $0 }
        let second = try await sequence.map { $0 }

        #expect(Set(first.map(\.name)) == Set(names))
        #expect(second.count == first.count)
        #expect(Set(second) == Set(first))

    }


    // The handle is opened outside the task: an open issued inside the already cancelled task
    // would report the cancellation itself and the iterator would never be reached.
    @Test
    func `Pre-cancelled next reports cancellation`() async throws {

        let path = try makeFiles(["file"])
        let handle = try await AsyncDirectoryHandle(forDirAt: path)

        await Support.expectPreCancelled {
            let sequence = handle.entrySequence()
            var iterator = sequence.makeAsyncIterator()
            return try await iterator.next()
        }

    }


    // Cancellation is checked before the buffer is served. A batch larger than the directory
    // fetches every entry on the first call, so the entries left after it are already sitting in
    // the iterator; once the task is cancelled, the next call reports the cancellation instead of
    // handing them out. The assertions run inside the cancelled task, where the iterator lives.
    @Test(.timeLimit(.minutes(1)))
    func `Cancellation wins over buffered entries`() async throws {

        let path = try makeFiles(["file-a", "file-b", "file-c"])
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let (fetched, fetchedContinuation) = AsyncStream.makeStream(of: Void.self)

        let task = Task {
            let sequence = handle.entrySequence(batchCount: 128)
            var iterator = sequence.makeAsyncIterator()
            let first = try await iterator.next()
            #expect(first != nil)
            #expect(iterator.ended == false)
            fetchedContinuation.yield()
            while !Task.isCancelled { await Task.yield() }

            let error = await #expect(throws: PlatformError.self) {
                try await iterator.next()
            }
            Support.expectStandardCancellation(error)
        }
        for await _ in fetched.prefix(1) {}
        task.cancel()

        try await task.value

    }

}
