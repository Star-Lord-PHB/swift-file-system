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
        at relativePath: FilePath,
        contents: Data = Data()
    ) throws -> FilePath {
        let absolutePath = path(relativePath)
        try createParentDirectory(for: absolutePath)
        try contents.write(to: URL(filePath: absolutePath.string))
        return absolutePath
    }

    @discardableResult
    func makeFile(
        at relativePath: String,
        contents: Data = Data()
    ) throws -> FilePath {
        try makeFile(at: FilePath(relativePath), contents: contents)
    }

    @discardableResult
    func makeFile(
        at relativePath: FilePath,
        contents: String
    ) throws -> FilePath {
        try makeFile(at: relativePath, contents: Data(contents.utf8))
    }

    @discardableResult
    func makeFile(
        at relativePath: String,
        contents: String
    ) throws -> FilePath {
        try makeFile(at: FilePath(relativePath), contents: Data(contents.utf8))
    }

    @discardableResult
    func makeDirectory(at relativePath: FilePath) throws -> FilePath {
        let absolutePath = path(relativePath)
        try FileManager.default.createDirectory(
            at: URL(filePath: absolutePath.string),
            withIntermediateDirectories: true
        )
        return absolutePath
    }

    @discardableResult
    func makeDirectory(at relativePath: String) throws -> FilePath {
        try makeDirectory(at: FilePath(relativePath))
    }

    @discardableResult
    func makeSymlink(
        at relativePath: FilePath,
        pointingTo target: FilePath
    ) throws -> FilePath {
        let absolutePath = path(relativePath)
        try createParentDirectory(for: absolutePath)
        try FileManager.default.createSymbolicLink(
            atPath: absolutePath.string,
            withDestinationPath: target.string
        )
        return absolutePath
    }

    @discardableResult
    func makeSymlink(
        at relativePath: String,
        pointingTo target: FilePath
    ) throws -> FilePath {
        try makeSymlink(at: FilePath(relativePath), pointingTo: target)
    }

    @discardableResult
    func makeFixture(
        at relativePath: FilePath,
        _ fixture: FileSystemTestSupport.Fixture
    ) throws -> FilePath {
        try createFixture(at: relativePath, fixture)
        return path(relativePath)
    }

    @discardableResult
    func makeFixture(
        at relativePath: String,
        _ fixture: FileSystemTestSupport.Fixture
    ) throws -> FilePath {
        try makeFixture(at: FilePath(relativePath), fixture)
    }

    private func createFixture(
        at relativePath: FilePath,
        _ fixture: FileSystemTestSupport.Fixture
    ) throws {
        switch fixture {
        case .file(let contents):
            try makeFile(at: relativePath, contents: contents)

        case .symlink(let target):
            try makeSymlink(at: relativePath, pointingTo: target)

        case .directory(let entries):
            try makeDirectory(at: relativePath)
            for (name, child) in entries {
                try createFixture(at: relativePath.appending(name), child)
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
