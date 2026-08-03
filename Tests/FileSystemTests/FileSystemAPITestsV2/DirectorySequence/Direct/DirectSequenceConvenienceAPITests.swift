import SystemPackage
import Testing
import SwiftFileSystem



extension DirectorySequenceAPITests.DirectTests {

    @Suite("Convenience APIs")
    struct ConvenienceAPITests {

        typealias Support = DirectorySequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension DirectorySequenceAPITests.DirectTests.ConvenienceAPITests {

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
    func `forEach visits every entry`() throws {

        let path = try createSampleDirectory()
        let sequence = try DirectoryEntryDirectSequence(dirAt: path)

        var paths = [FilePath]()
        try sequence.forEach { result in
            paths.append(try result.get().path)
        }

        #expect(paths.count == sampleDirectoryEntryPaths.count)
        #expect(Set(paths) == sampleDirectoryEntryPaths)

    }


    @Test
    func `map transforms every entry`() throws {

        let path = try createSampleDirectory()
        let sequence = try DirectoryEntryDirectSequence(dirAt: path)

        let names = try sequence.map { result in
            try result.get().name
        }

        #expect(names.count == sampleDirectoryEntryPaths.count)
        #expect(Set(names.map { FilePath($0) }) == sampleDirectoryEntryPaths)

    }


    @Test
    func `compactMap drops nil transform results`() throws {

        let path = try createSampleDirectory()
        let sequence = try DirectoryEntryDirectSequence(dirAt: path)

        let regularFilePaths = try sequence.compactMap { result in
            let entry = try result.get()
            return entry.type == .regular ? entry.path : nil
        }

        #expect(Set(regularFilePaths) == ["file-a", "file-b"])

    }


    @Test
    func `reduce combines every entry`() throws {

        let path = try createSampleDirectory()
        let sequence = try DirectoryEntryDirectSequence(dirAt: path)

        let paths = try sequence.reduce([FilePath]()) { partialResult, result in
            partialResult + [try result.get().path]
        }

        #expect(paths.count == sampleDirectoryEntryPaths.count)
        #expect(Set(paths) == sampleDirectoryEntryPaths)

    }


    @Test
    func `reduce-into combines every entry`() throws {

        let path = try createSampleDirectory()
        let sequence = try DirectoryEntryDirectSequence(dirAt: path)

        var paths = Set<FilePath>()
        try sequence.reduce(into: &paths) { partialResult, result in
            partialResult.insert(try result.get().path)
        }

        #expect(paths == sampleDirectoryEntryPaths)

    }

}
