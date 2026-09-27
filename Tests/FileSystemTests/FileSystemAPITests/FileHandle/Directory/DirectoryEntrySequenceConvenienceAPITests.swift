import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests.DirectoryTests.EntrySequenceTests {

    @Suite("Convenience APIs")
    struct ConvenienceAPITests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.DirectoryTests.EntrySequenceTests.ConvenienceAPITests {

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
        let handle = try DirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        var paths = [FilePath]()
        try sequence.forEach { entry in
            paths.append(entry.path)
        }

        #expect(paths.count == sampleDirectoryEntryPaths.count)
        #expect(Set(paths) == sampleDirectoryEntryPaths)

    }


    @Test
    func `map transforms every entry`() throws {

        let path = try createSampleDirectory()
        let handle = try DirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        let names = try sequence.map { entry in
            entry.name.string
        }

        #expect(names.count == sampleDirectoryEntryPaths.count)
        #expect(Set(names.map { FilePath($0) }) == sampleDirectoryEntryPaths)

    }


    @Test
    func `compactMap drops nil transform results`() throws {

        let path = try createSampleDirectory()
        let handle = try DirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        let regularFilePaths = try sequence.compactMap { entry in
            return entry.type == .regular ? entry.path : nil
        }

        #expect(Set(regularFilePaths) == ["file-a", "file-b"])

    }


    @Test
    func `reduce combines every entry`() throws {

        let path = try createSampleDirectory()
        let handle = try DirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        let paths = try sequence.reduce([FilePath]()) { partialResult, entry in
            partialResult + [entry.path]
        }

        #expect(paths.count == sampleDirectoryEntryPaths.count)
        #expect(Set(paths) == sampleDirectoryEntryPaths)

    }


    @Test
    func `reduce-into combines every entry`() throws {

        let path = try createSampleDirectory()
        let handle = try DirectoryHandle(forDirAt: path)
        let sequence = handle.entrySequence()

        var paths = Set<FilePath>()
        try sequence.reduce(into: &paths) { partialResult, entry in
            partialResult.insert(entry.path)
        }

        #expect(paths == sampleDirectoryEntryPaths)

    }

}
