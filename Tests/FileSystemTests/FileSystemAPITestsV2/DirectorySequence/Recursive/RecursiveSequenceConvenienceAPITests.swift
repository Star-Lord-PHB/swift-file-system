import SystemPackage
import Testing
import SwiftFileSystem



extension DirectorySequenceAPITests.RecursiveTests {

    @Suite("Convenience APIs")
    struct ConvenienceAPITests {

        typealias Support = DirectorySequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension DirectorySequenceAPITests.RecursiveTests.ConvenienceAPITests {

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
    func `forEach visits every element`() throws {

        let path = try createSampleDirectory()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)

        var paths = [FilePath]()
        try sequence.forEach { result in
            paths.append(try result.get().path)
        }

        #expect(paths.count == sampleDirectoryElementPaths.count)
        #expect(Set(paths) == Set(sampleDirectoryElementPaths))

    }


    @Test
    func `map transforms every element`() throws {

        let path = try createSampleDirectory()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)

        let names = try sequence.map { result in
            try result.get().name
        }

        #expect(names.count == sampleDirectoryElementPaths.count)
        #expect(Set(names) == Set(sampleDirectoryElementPaths.compactMap(\.lastComponent)))

    }


    @Test
    func `compactMap drops nil transform results`() throws {

        let path = try createSampleDirectory()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)

        let regularFilePaths = try sequence.compactMap { result in
            if case .entry(let entry) = try result.get(), entry.type == .regular {
                entry.path
            } else {
                nil as FilePath?
            }
        }

        #expect(Set(regularFilePaths) == ["file", "subdir/nested"])

    }


    @Test
    func `reduce combines every element`() throws {

        let path = try createSampleDirectory()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)

        let paths = try sequence.reduce([FilePath]()) { partialResult, result in
            partialResult + [try result.get().path]
        }

        #expect(paths.count == sampleDirectoryElementPaths.count)
        #expect(Set(paths) == Set(sampleDirectoryElementPaths))

    }


    @Test
    func `reduce-into combines every element`() throws {

        let path = try createSampleDirectory()
        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)

        var paths = [FilePath]()
        try sequence.reduce(into: &paths) { partialResult, result in
            partialResult.append(try result.get().path)
        }

        #expect(paths.count == sampleDirectoryElementPaths.count)
        #expect(Set(paths) == Set(sampleDirectoryElementPaths))

    }

}
