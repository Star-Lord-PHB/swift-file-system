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
