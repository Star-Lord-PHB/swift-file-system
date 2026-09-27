import SystemPackage
import Testing
import SwiftFileSystem



extension ResourceLifetimeTests {

    @Suite("Enumeration")
    struct EnumerationLeakTests {

        typealias Support = ResourceLifetimeTests.Support

        typealias LeakChecker = ResourceLifetimeTests.LeakChecker

        let fileSystem = FileSystem()
        let workspace: Support.Workspace
        let root: FilePath


        init() throws {
            workspace = try Support.Workspace()
            root = try workspace.makeFixture(
                at: "tree",
                [
                    "file-a.txt": .file(contents: "a"),
                    "sub": [
                        "file-b.txt": .file(contents: "b"),
                        "deeper": [
                            "file-c.txt": .file(contents: "c")
                        ],
                    ],
                    "sub2": [
                        "file-d.txt": .file(contents: "d")
                    ],
                ]
            )
        }

    }

}



extension ResourceLifetimeTests.EnumerationLeakTests {

    @Test
    func `contentsOfDirectory does not leak resources`() throws {

        try LeakChecker.expectNoLeak {
            _ = try fileSystem.contentsOfDirectory(at: root)
        }

    }


    @Test
    func `Fully consumed entry sequence does not leak resources`() throws {

        try LeakChecker.expectNoLeak {
            let handle = try DirectoryHandle(forDirAt: root)
            try handle.entrySequence().forEach { e in
                _ = e
            }
        }

    }


    @Test
    func `Abandoned entry iteration does not leak resources`() throws {

        // Stopping after the first entry leaves the reopened directory stream to the drop of the
        // iterator rather than to a completed enumeration.
        try LeakChecker.expectNoLeak {
            let handle = try DirectoryHandle(forDirAt: root)
            let sequence = handle.entrySequence()
            var iterator = sequence.makeIterator()
            let first = try iterator.next()
            #expect(first != nil)
        }

    }


    @Test
    func `Fully consumed recursive sequence does not leak resources`() throws {

        try LeakChecker.expectNoLeak {
            let sequence = DirectoryEntryRecursiveSequence(dirAt: root)
            try sequence.forEach { e in
                _ = e
            }
        }

    }


    @Test
    func `Abandoned recursive iteration does not leak resources`() throws {

        // Stopping at the deepest entry guarantees the enumerator still holds the whole
        // stack of directory handles when it is dropped.
        try LeakChecker.expectNoLeak {
            var iterator = DirectoryEntryRecursiveSequence(dirAt: root).makeIterator()
            var reachedDeepestEntry = false
            while let e = try iterator.next() {
                if case .entry(let entry) = e,
                    entry.path.lastComponent == "file-c.txt" {
                    reachedDeepestEntry = true
                    break
                }
            }
            #expect(reachedDeepestEntry)
        }

    }


    @Test
    func `Recursive sequence root failure does not leak resources`() throws {

        let filePath = try workspace.makeFile(at: "file.txt", contents: "contents")
        let missing = workspace.path("missing")

        try LeakChecker.expectNoLeak {
            for path in [filePath, missing] {
                var iterator = DirectoryEntryRecursiveSequence(dirAt: path).makeIterator()
                #expect(throws: PlatformError.self) {
                    _ = try iterator.next()
                }
            }
        }

    }

}
