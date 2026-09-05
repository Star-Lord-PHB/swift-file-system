import SystemPackage
import Testing
import SwiftFileSystem



extension RecursiveSequenceAPITests {

    @Suite("Error handling")
    struct ErrorHandlingTests {

        typealias Support = RecursiveSequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension RecursiveSequenceAPITests.ErrorHandlingTests {

    /// Recursive-traversal elements grouped by case, keeping the reported errors.
    struct TraversalLog {

        var entries = [DirectoryEntry]()
        var cleanLeavingDirectories = [FilePath]()
        var leavingDirectoryErrors = [(path: FilePath, error: PlatformError)]()
        var entryErrors = [(path: FilePath, error: PlatformError)]()
        var subTreeErrors = [(path: FilePath, error: PlatformError)]()

        init(elements: [DirectoryEntryRecursiveSequenceElement]) {
            for element in elements {
                switch element {
                case .entry(let entry):
                    entries.append(entry)
                case .leavingDir(let path, nil):
                    cleanLeavingDirectories.append(path)
                case .leavingDir(let path, let error?):
                    leavingDirectoryErrors.append((path, error))
                case .entryError(let path, let error):
                    entryErrors.append((path, error))
                case .subTreeError(let path, let error):
                    subTreeErrors.append((path, error))
                }
            }
        }

    }

}



extension RecursiveSequenceAPITests.ErrorHandlingTests {

    @Test
    func `Recursive sequence reports a missing root and ends`() throws {

        let path = workspace.path("missing")

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeIterator()

        let first = iterator.next()
        let error = #expect(throws: PlatformError.self) {
            try first?.get()
        }
        #expect(error?.kind == .notFound)
        #expect(iterator.next() == nil)

    }


    @Test
    func `Recursive sequence reports a regular file root and ends`() throws {

        let path = try workspace.makeFile(at: "file")

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeIterator()

        let first = iterator.next()
        let error = #expect(throws: PlatformError.self) {
            try first?.get()
        }
        #expect(error?.kind == .notADirectory)
        #expect(iterator.next() == nil)

    }


    @Test
    func `Recursive sequence reports a dangling symlink root and ends`() throws {

        let path = try workspace.makeSymlink(at: "dangling", pointingTo: "missing")

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        var iterator = sequence.makeIterator()

        let first = iterator.next()
        let error = #expect(throws: PlatformError.self) {
            try first?.get()
        }
        #if canImport(WinSDK)
        // NOTE: FindFirstFile reports ERROR_DIRECTORY for a dangling symlink root, the same native
        // code as for a regular-file root; the two cases cannot be told apart without an extra
        // path probe. POSIX FTS identifies the dangling root itself and reports notFound, matching
        // the direct sequence on both platforms.
        #expect(error?.kind == .notADirectory)
        #else
        #expect(error?.kind == .notFound)
        #endif
        #expect(iterator.next() == nil)

    }

}
