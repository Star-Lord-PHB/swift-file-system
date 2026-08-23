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
