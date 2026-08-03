#if !canImport(WinSDK)

import PlatformCLib
import SystemPackage
import Testing
import SwiftFileSystem



extension DirectorySequenceAPITests {

    @Suite("POSIX entry kinds")
    struct POSIXEntryKindTests {

        typealias Support = DirectorySequenceAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension DirectorySequenceAPITests.POSIXEntryKindTests {

    @Test
    func `Direct sequence reports the fifo entry kind`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let fifoPath = path.appending("fifo")
        try #require(mkfifo(fifoPath.string, 0o644) == 0)

        let sequence = try DirectoryEntryDirectSequence(dirAt: path)
        let entries = try sequence.map { result in
            try result.get()
        }

        try #require(entries.count == 1)
        #expect(entries[0].path == "fifo")
        #expect(entries[0].type == .fifo)

    }


    @Test
    func `Recursive sequence reports the fifo entry kind`() throws {

        let path = try workspace.makeDirectory(at: "directory")
        let fifoPath = path.appending("fifo")
        try #require(mkfifo(fifoPath.string, 0o644) == 0)

        let sequence = DirectoryEntryRecursiveSequence(dirAt: path)
        let elements = try sequence.map { result in
            try result.get()
        }

        try #require(elements.count == 1)
        guard case .entry(let entry) = elements[0] else {
            Issue.record("Expected an entry element, got \(elements[0])")
            return
        }
        #expect(entry.path == "fifo")
        #expect(entry.type == .fifo)

    }

}

#endif
