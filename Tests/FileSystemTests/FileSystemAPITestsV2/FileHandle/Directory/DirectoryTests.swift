import SystemPackage
import Testing
import SwiftFileSystem



extension FileHandleAPITests {

    @Suite("Directory")
    struct DirectoryTests {

        typealias Support = FileHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileHandleAPITests.DirectoryTests {

    struct RecursiveContents {

        var entries = Set<DirectoryEntry>()
        var leavingDirectories = Set<FilePath>()

    }


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


    func recursiveContents(
        from elements: [DirectoryEntryRecursiveSequenceElement]
    ) throws -> RecursiveContents {
        var contents = RecursiveContents()

        for element in elements {
            switch element {
            case .entry(let entry):
                contents.entries.insert(entry)

            case .leavingDir(let path, nil):
                contents.leavingDirectories.insert(path)

            case .leavingDir(_, let error?),
                 .entryError(_, let error),
                 .subTreeError(_, let error):
                throw error
            }
        }

        return contents
    }


    func expectEntries(
        _ entries: [DirectoryEntry],
        match expected: Set<DirectoryEntry>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(entries.count == expected.count, sourceLocation: sourceLocation)
        #expect(Set(entries) == expected, sourceLocation: sourceLocation)
    }


    func expectRecursiveDirContents(
        _ contents: RecursiveContents,
        entries expectedEntries: Set<DirectoryEntry>,
        leavingDirectories expectedLeavingDirectories: Set<FilePath>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(contents.entries == expectedEntries, sourceLocation: sourceLocation)
        #expect(
            contents.leavingDirectories == expectedLeavingDirectories,
            sourceLocation: sourceLocation
        )
    }

}
