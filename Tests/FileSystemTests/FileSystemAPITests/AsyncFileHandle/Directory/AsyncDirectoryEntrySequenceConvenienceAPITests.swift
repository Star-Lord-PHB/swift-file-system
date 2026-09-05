import Testing
import SwiftAsyncFileSystem



extension AsyncFileHandleAPITests.DirectoryTests.EntrySequenceTests {

    @Suite("Convenience APIs")
    struct ConvenienceAPITests {

        typealias Support = AsyncFileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncFileHandleAPITests.DirectoryTests.EntrySequenceTests.ConvenienceAPITests {

    private var sampleDirectoryEntryPaths: Set<FilePath> { ["file-a", "file-b", "subdir"] }


    private func createSampleDirectory() throws -> FilePath {
        try workspace.makeFixture(
            at: "directory",
            [
                "file-a": .file(contents: "a"),
                "file-b": .file(contents: "b"),
                "subdir": [:]
            ]
        )
    }


    @Test
    func `forEach visits every entry`() async throws {

        let path = try createSampleDirectory()
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        var paths = [FilePath]()
        try await sequence.forEach { entry in
            paths.append(entry.path)
        }

        #expect(paths.count == sampleDirectoryEntryPaths.count)
        #expect(Set(paths) == sampleDirectoryEntryPaths)

    }


    @Test
    func `map transforms every entry`() async throws {

        let path = try createSampleDirectory()
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        let names = try await sequence.map { entry in
            entry.name
        }

        #expect(names.count == sampleDirectoryEntryPaths.count)
        #expect(Set(names.map { FilePath($0) }) == sampleDirectoryEntryPaths)

    }


    @Test
    func `compactMap drops nil transform results`() async throws {

        let path = try createSampleDirectory()
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        let regularFilePaths = try await sequence.compactMap { entry in
            entry.type == .regular ? entry.path : nil
        }

        #expect(Set(regularFilePaths) == ["file-a", "file-b"])

    }


    @Test
    func `reduce combines every entry`() async throws {

        let path = try createSampleDirectory()
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        let paths = try await sequence.reduce([FilePath]()) { partialResult, entry in
            partialResult + [entry.path]
        }

        #expect(paths.count == sampleDirectoryEntryPaths.count)
        #expect(Set(paths) == sampleDirectoryEntryPaths)

    }


    @Test
    func `reduce-into combines every entry`() async throws {

        let path = try createSampleDirectory()
        let handle = try await AsyncDirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        var paths = Set<FilePath>()
        try await sequence.reduce(into: &paths) { partialResult, entry in
            partialResult.insert(entry.path)
        }

        #expect(paths == sampleDirectoryEntryPaths)

    }

}
