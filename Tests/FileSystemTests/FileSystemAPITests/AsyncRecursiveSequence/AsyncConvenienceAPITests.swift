import Testing
import SwiftAsyncFileSystem



extension AsyncRecursiveSequenceAPITests {

    @Suite("Convenience APIs")
    struct ConvenienceAPITests {

        typealias Support = AsyncRecursiveSequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension AsyncRecursiveSequenceAPITests.ConvenienceAPITests {

    // every element path, including the leaving-directory marker of "subdir"
    private var sampleDirectoryElementPaths: [FilePath] {
        ["file", "subdir", "subdir/nested", "subdir"]
    }


    private func createSampleDirectory() throws -> FilePath {
        try workspace.makeFixture(
            at: "directory",
            [
                "file": .file(contents: "contents"),
                "subdir": [
                    "nested": .file(contents: "nested contents")
                ]
            ]
        )
    }


    @Test
    func `forEach visits every element`() async throws {

        let path = try createSampleDirectory()
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        var paths = [FilePath]()
        try await sequence.forEach { element in
            paths.append(element.path)
        }

        #expect(paths.count == sampleDirectoryElementPaths.count)
        #expect(Set(paths) == Set(sampleDirectoryElementPaths))

    }


    @Test
    func `map transforms every element`() async throws {

        let path = try createSampleDirectory()
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        let names = try await sequence.map { element in
            element.name
        }

        #expect(names.count == sampleDirectoryElementPaths.count)
        #expect(Set(names) == Set(sampleDirectoryElementPaths.compactMap(\.lastComponent)))

    }


    @Test
    func `compactMap drops nil transform results`() async throws {

        let path = try createSampleDirectory()
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        let regularFilePaths = try await sequence.compactMap { element in
            if case .entry(let entry) = element, entry.type == .regular {
                entry.path
            } else {
                nil as FilePath?
            }
        }

        #expect(Set(regularFilePaths) == ["file", "subdir/nested"])

    }


    @Test
    func `reduce combines every element`() async throws {

        let path = try createSampleDirectory()
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        let paths = try await sequence.reduce([FilePath]()) { partialResult, element in
            partialResult + [element.path]
        }

        #expect(paths.count == sampleDirectoryElementPaths.count)
        #expect(Set(paths) == Set(sampleDirectoryElementPaths))

    }


    @Test
    func `reduce-into combines every element`() async throws {

        let path = try createSampleDirectory()
        let sequence = AsyncDirectoryEntryRecursiveSequence(dirAt: path)

        var paths = [FilePath]()
        try await sequence.reduce(into: &paths) { partialResult, element in
            partialResult.append(element.path)
        }

        #expect(paths.count == sampleDirectoryElementPaths.count)
        #expect(Set(paths) == Set(sampleDirectoryElementPaths))

    }

}
