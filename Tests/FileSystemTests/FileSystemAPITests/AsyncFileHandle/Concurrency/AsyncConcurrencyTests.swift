import Foundation
import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests {

    @Suite("Concurrency")
    struct ConcurrencyTests {

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



// NOTE: The positional handles and the append handle are Sendable so that one handle can
// serve several tasks at once; that is the shape without a synchronous counterpart covered
// here. A noncopyable handle is captured by reference, so the child-task closures are marked
// @Sendable to share it (Swift 6.3), and the handle is left to deinit afterwards since a
// captured handle cannot be consumed. Concurrent I/O on the non-Sendable streaming handles
// is rejected at compile time and needs no test.
extension AsyncFileHandleAPITests.ConcurrencyTests {

    private static let chunkCount = 16
    private static let chunkSize = 4


    private static func chunk(_ index: Int) -> ByteBuffer {
        ByteBuffer(repeating: UInt8(0x41 + index), count: chunkSize)
    }


    private static func chunkedContents() -> ByteBuffer {
        var contents = ByteBuffer()
        for index in 0 ..< chunkCount {
            contents.append(contentsOf: chunk(index))
        }
        return contents
    }


    private static let recordSize = 8


    private static func record(task: Int, sequence: Int) -> ByteBuffer {
        let text = Array("t\(task)s\(sequence)\n".utf8)
        let padding = [UInt8](repeating: 0x2D, count: recordSize)
        return ByteBuffer((text + padding).prefix(recordSize))
    }


    @Test(.timeLimit(.minutes(1)))
    func `Concurrent positional reads share one handle`() async throws {

        let path = try workspace.makeFile(at: "file", contents: Data(Self.chunkedContents()))
        let handle = try await AsyncReadFileHandle(forFileAt: path)

        let chunks = try await withThrowingTaskGroup(of: (Int, ByteBuffer).self) { group in
            for index in 0 ..< Self.chunkCount {
                group.addTask { @Sendable in
                    let offset = Int64(index * Self.chunkSize)
                    return (index, try await handle.read(fromOffset: offset, length: Int64(Self.chunkSize)))
                }
            }
            var chunks = [Int: ByteBuffer]()
            for try await (index, chunk) in group {
                chunks[index] = chunk
            }
            return chunks
        }

        for index in 0 ..< Self.chunkCount {
            #expect(chunks[index] == Self.chunk(index))
        }

    }


    @Test(.timeLimit(.minutes(1)))
    func `Concurrent positional writes share one handle`() async throws {

        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncWriteFileHandle(forFileAt: path)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< Self.chunkCount {
                group.addTask { @Sendable in
                    let offset = Int64(index * Self.chunkSize)
                    let bytesWritten = try await handle.write(Self.chunk(index), toOffset: offset)
                    #expect(bytesWritten == Int64(Self.chunkSize))
                }
            }
            try await group.waitForAll()
        }

        #expect(try capturedContents(at: path) == Self.chunkedContents())

    }


    // Every record is appended with the native append-at-end semantics, so the records are
    // expected to land whole in some order: the file holds exactly the set of records, with
    // none torn or interleaved.
    @Test(.timeLimit(.minutes(1)))
    func `Concurrent appends land whole records`() async throws {

        let taskCount = 8
        let appendsPerTask = 8
        let path = try workspace.makeFile(at: "file")
        let handle = try await AsyncAppendHandle(forFileAt: path)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in 0 ..< taskCount {
                group.addTask { @Sendable in
                    for sequence in 0 ..< appendsPerTask {
                        let bytesAppended = try await handle.append(Self.record(task: task, sequence: sequence))
                        #expect(bytesAppended == Int64(Self.recordSize))
                    }
                }
            }
            try await group.waitForAll()
        }

        let contents = try capturedContents(at: path)
        #expect(contents.count == taskCount * appendsPerTask * Self.recordSize)

        var landedRecords = Set<ByteBuffer>()
        for start in stride(from: 0, to: contents.count, by: Self.recordSize) {
            landedRecords.insert(ByteBuffer(contents[start ..< start + Self.recordSize]))
        }
        var expectedRecords = Set<ByteBuffer>()
        for task in 0 ..< taskCount {
            for sequence in 0 ..< appendsPerTask {
                expectedRecords.insert(Self.record(task: task, sequence: sequence))
            }
        }
        #expect(landedRecords == expectedRecords)

    }


    // The directory handle is Sendable as well: every listing reopens the directory for a cursor
    // of its own, so concurrent listings through one handle must each see the whole directory.
    @Test(.timeLimit(.minutes(1)))
    func `Concurrent listings share one handle`() async throws {

        let taskCount = 8
        let path = try workspace.makeFixture(
            at: "directory",
            [
                "file-a": .file(contents: "a"),
                "file-b": .file(contents: "b"),
                "file-c": .file(contents: "c"),
                "subdir": [:]
            ]
        )
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let expectedNames: Set<String> = ["file-a", "file-b", "file-c", "subdir"]

        let listings = try await withThrowingTaskGroup(of: [DirectoryEntry].self) { group in
            for _ in 0 ..< taskCount {
                group.addTask { @Sendable in
                    try await handle.entries()
                }
            }
            var listings = [[DirectoryEntry]]()
            for try await listing in group {
                listings.append(listing)
            }
            return listings
        }

        #expect(listings.count == taskCount)
        for listing in listings {
            #expect(listing.count == expectedNames.count)
            #expect(Set(listing.map(\.name)) == expectedNames)
        }

    }

}
