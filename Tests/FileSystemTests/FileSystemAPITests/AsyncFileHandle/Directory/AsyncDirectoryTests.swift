import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests {

    @Suite("Directory")
    struct DirectoryTests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



// NOTE: `AsyncDirectoryHandle` is made of two kinds of code. The initializer, `close()` and the
// metadata family are executor dispatch of the synchronous `DirectoryHandle` and get forwarding
// and pre-cancelled tests only. The entry sequence is an engine of its own: its iterator drives
// the synchronous `EntryIterator` on the executor in batches, so batching, buffered entries,
// `ended` and cancellation are pinned here, while the listing semantics produced by the
// synchronous iterator (dot entries, skip-dir, symlink roots, one reopen per iterator) stay
// covered by the synchronous `FileHandle/Directory` group and only get option forwarding checks.
extension AsyncFileHandleAPITests.DirectoryTests {

    func entry(
        _ path: FilePath,
        type: FileKind,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> DirectoryEntry {
        try #require(
            DirectoryEntry(path: path, type: type),
            sourceLocation: sourceLocation
        )
    }


    func expectEntries(
        _ entries: [DirectoryEntry],
        match expected: Set<DirectoryEntry>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(entries.count == expected.count, sourceLocation: sourceLocation)
        #expect(Set(entries) == expected, sourceLocation: sourceLocation)
    }

}
