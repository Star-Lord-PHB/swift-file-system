import Foundation
import SystemPackage

/// A declarative fixture used to create a file or an entire directory tree.
extension FileSystemTestSupport {

    indirect enum Fixture: ExpressibleByDictionaryLiteral {

        case file(contents: Data = Data())
        case symlink(target: FilePath)
        case directory([FilePath.Component: Fixture])

        init(dictionaryLiteral elements: (FilePath.Component, Fixture)...) {
            self = .directory(Dictionary(uniqueKeysWithValues: elements))
        }

        static func file(contents: String) -> Fixture {
            .file(contents: Data(contents.utf8))
        }

    }

}

extension FileSystemTestSupport.Workspace {

    @discardableResult
    func makeFile(
        at itemPath: FilePath,
        contents: Data = Data()
    ) throws -> FilePath {
        let absolutePath = path(itemPath)
        try createParentDirectory(for: absolutePath)
        try contents.write(to: URL(filePath: absolutePath.string))
        return absolutePath
    }

    @discardableResult
    func makeFile(
        at itemPath: String,
        contents: Data = Data()
    ) throws -> FilePath {
        try makeFile(at: FilePath(itemPath), contents: contents)
    }

    @discardableResult
    func makeFile(
        at itemPath: FilePath,
        contents: String
    ) throws -> FilePath {
        try makeFile(at: itemPath, contents: Data(contents.utf8))
    }

    @discardableResult
    func makeFile(
        at itemPath: String,
        contents: String
    ) throws -> FilePath {
        try makeFile(at: FilePath(itemPath), contents: Data(contents.utf8))
    }

    @discardableResult
    func makeDirectory(at itemPath: FilePath) throws -> FilePath {
        let absolutePath = path(itemPath)
        try FileManager.default.createDirectory(
            at: URL(filePath: absolutePath.string),
            withIntermediateDirectories: true
        )
        return absolutePath
    }

    @discardableResult
    func makeDirectory(at itemPath: String) throws -> FilePath {
        try makeDirectory(at: FilePath(itemPath))
    }

    @discardableResult
    func makeSymlink(
        at itemPath: FilePath,
        pointingTo target: FilePath
    ) throws -> FilePath {
        let absolutePath = path(itemPath)
        try createParentDirectory(for: absolutePath)
        try FileManager.default.createSymbolicLink(
            atPath: absolutePath.string,
            withDestinationPath: target.string
        )
        return absolutePath
    }

    @discardableResult
    func makeSymlink(
        at itemPath: String,
        pointingTo target: FilePath
    ) throws -> FilePath {
        try makeSymlink(at: FilePath(itemPath), pointingTo: target)
    }

    @discardableResult
    func makeFixture(
        at itemPath: FilePath,
        _ fixture: FileSystemTestSupport.Fixture
    ) throws -> FilePath {
        try createFixture(at: itemPath, fixture)
        return path(itemPath)
    }

    @discardableResult
    func makeFixture(
        at itemPath: String,
        _ fixture: FileSystemTestSupport.Fixture
    ) throws -> FilePath {
        try makeFixture(at: FilePath(itemPath), fixture)
    }

    private func createFixture(
        at itemPath: FilePath,
        _ fixture: FileSystemTestSupport.Fixture
    ) throws {
        switch fixture {
        case .file(let contents):
            try makeFile(at: itemPath, contents: contents)

        case .symlink(let target):
            try makeSymlink(at: itemPath, pointingTo: target)

        case .directory(let entries):
            try makeDirectory(at: itemPath)
            for (name, child) in entries {
                try createFixture(at: itemPath.appending(name), child)
            }
        }
    }

    private func createParentDirectory(for absolutePath: FilePath) throws {
        let parent = absolutePath.removingLastComponent()
        try FileManager.default.createDirectory(
            at: URL(filePath: parent.string),
            withIntermediateDirectories: true
        )
    }

}

extension FileSystemTestSupport.Workspace {

    /// Creates a file of exactly `byteCount` bytes whose contents differ from block to block.
    ///
    /// The file is written in `largeFileBlockSize` blocks. Each block has its own fill byte and
    /// every 4 KiB page starts with its page index, so a copy that drops, repeats or reorders a
    /// block, or stops short of the end, differs from the source in a byte-for-byte comparison.
    @discardableResult
    func makeLargeFile(at itemPath: FilePath, byteCount: Int) throws -> FilePath {
        precondition(byteCount >= 0)
        let absolutePath = path(itemPath)
        try createParentDirectory(for: absolutePath)
        let url = URL(filePath: absolutePath.string)
        try Data().write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        var offset = 0
        while offset < byteCount {
            let blockIndex = offset / Self.largeFileBlockSize
            let length = min(Self.largeFileBlockSize, byteCount - offset)
            try handle.write(contentsOf: Self.largeFileBlock(index: blockIndex, length: length))
            offset += length
        }
        try handle.close()
        return absolutePath
    }

    @discardableResult
    func makeLargeFile(at itemPath: String, byteCount: Int) throws -> FilePath {
        try makeLargeFile(at: FilePath(itemPath), byteCount: byteCount)
    }

    static let largeFileBlockSize = 1 << 20

    /// The contents of block `index` of a large file, truncated to `length` bytes.
    static func largeFileBlock(index: Int, length: Int) -> Data {
        precondition(length >= 0 && length <= largeFileBlockSize)
        // An odd multiplier keeps the fill bytes of the first 256 blocks distinct, and the offset
        // keeps block 0 away from all zeros.
        var block = Data(repeating: UInt8(truncatingIfNeeded: index &* 37 &+ 11), count: length)
        let pageSize = 4096
        let firstPageIndex = index * (largeFileBlockSize / pageSize)
        for pageOffset in stride(from: 0, to: length, by: pageSize) {
            let pageIndex = firstPageIndex + pageOffset / pageSize
            for byteIndex in 0 ..< min(4, length - pageOffset) {
                block[pageOffset + byteIndex] = UInt8(truncatingIfNeeded: pageIndex >> (8 * byteIndex))
            }
        }
        return block
    }

}
