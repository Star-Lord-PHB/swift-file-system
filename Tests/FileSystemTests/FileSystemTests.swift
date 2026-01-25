import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore

#if canImport(WinSDK)
import WinSDK
#endif 


// Tests of the FileSystem APIs will include resource handle leakage check, which does not work correctly
// in parallel testing
@Suite(.serialized)
class FileSystemTest {

    static let rootDir: FilePath = .init(URL.temporaryDirectory.path).appending("swift-file-system-tests")

    let testId: String
    
    var testDir: FilePath { Self.rootDir.appending(testId.description) }


    init() throws {
        let test = try #require(Test.current, "Must be run inside a test")
        self.testId = "\(test.name)-\(UUID().uuidString)"
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "_")
        try FileManager.default.createDirectory(at: .init(filePath: testDir.string), withIntermediateDirectories: true)
    }


    deinit {
        try? FileManager.default.removeItem(at: .init(filePath: testDir.string))
    }


    func makePath(at path: FilePath) -> FilePath {
        precondition(path.isRelative, "Path must be relative")
        return testDir.appending(path.components)
    }


    func makeFile(at path: FilePath, contents: Data = .init()) throws -> FilePath {

        precondition(path.isRelative, "Path must be relative")

        let absPath = testDir.appending(path.components)

        if (path.components.count > 1) {
            let parent = absPath.removingLastComponent()
            try FileManager.default.createDirectory(at: .init(filePath: parent.string), withIntermediateDirectories: true)
        }

        try contents.write(to: .init(filePath: absPath.string))

        return absPath

    }


    func makeSymlink(at path: FilePath, pointingTo target: FilePath) throws -> FilePath {

        precondition(path.isRelative, "Path must be relative")

        let absPath = testDir.appending(path.components)

        let parent = absPath.removingLastComponent()
        try FileManager.default.createDirectory(at: .init(filePath: parent.string), withIntermediateDirectories: true)

        try FileManager.default.createSymbolicLink(atPath: absPath.string, withDestinationPath: target.string)

        return absPath

    }


    func makeDir(at path: FilePath) throws -> FilePath {

        precondition(path.isRelative, "Path must be relative")

        let absPath = testDir.appending(path.components)
        try FileManager.default.createDirectory(at: .init(filePath: absPath.string), withIntermediateDirectories: true)

        return absPath

    }


    enum FileStructure: ExpressibleByDictionaryLiteral {
        case file(contents: Data? = nil)
        case symlink(target: FilePath)
        case directory([FilePath.Component: FileStructure])

        init(dictionaryLiteral elements: (FilePath.Component, FileStructure)...) {
            self = .directory(.init(uniqueKeysWithValues: elements))
        }

        static func file(contents: String) -> FileStructure {
            return .file(contents: Data(contents.utf8))
        }
    }


    private func _makeFileStructure(at path: FilePath, structure: FileStructure) throws {
        switch structure {
            case .file(let contents):
                _ = try makeFile(at: path, contents: contents ?? .init())
            case .symlink(let target):
                _ = try makeSymlink(at: path, pointingTo: target)
            case .directory(let entries):
                _ = try makeDir(at: path)
                for (name, entryStructure) in entries {
                    let entryPath = path.appending(name)
                    try _makeFileStructure(at: entryPath, structure: entryStructure)
                }
        }
    }


    func makeFileStructure(at path: FilePath, structure: FileStructure) throws -> FilePath {
        precondition(path.isRelative, "Path must be relative")
        try _makeFileStructure(at: path, structure: structure)
        let absPath = testDir.appending(path.components)
        return absPath
    }


    func currentOpenedHandleCount() throws -> Int64 {

        #if canImport(WinSDK)

        var count = 0 as DWORD
        GetProcessHandleCount(GetCurrentProcess(), &count)
        return Int64(count)

        #elseif canImport(Darwin)

        return Int64(Int(proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, nil, 0)) / MemoryLayout<proc_fdinfo>.size)

        #else

        var count = 0 as Int64
        let procFdDir = try #require(opendir("/proc/self/fd"))
        defer { closedir(procFdDir) }
        while readdir(procFdDir) != nil {
            count += 1
        }
        return count - 2

        #endif

    }


    func accessTime(ofItemAt path: FilePath) throws -> Date {
        #if canImport(WinSDK)
        var info = WIN32_FILE_ATTRIBUTE_DATA()
        let success = path.withPlatformString { pathPtr in 
            GetFileAttributesExW(pathPtr, GetFileExInfoStandard, &info)
        }
        guard success else {
            throw SystemError(code: .system(.init(rawValue: GetLastError())))!
        }
        let accessTimeSpec = info.ftLastAccessTime
        let totalNanoseconds = ((UInt64(accessTimeSpec.dwHighDateTime) << 32) | UInt64(accessTimeSpec.dwLowDateTime)) * 100
        let seconds = totalNanoseconds / 1_000_000_000
        let nanoseconds = totalNanoseconds % 1_000_000_000
        let timeInterval = TimeInterval(seconds) - 12622780800 + TimeInterval(nanoseconds) / 1_000_000_000
        return Date(timeIntervalSinceReferenceDate: timeInterval)
        #else
        return try URL(filePath: path.string).resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate!
        #endif 
    }


    func expectNoResHandleLeak<R>(
        sourceLocation: SourceLocation = #_sourceLocation,
        operation: () async throws -> sending R
    ) async throws -> sending R {

        let openedHandleCountBefore = try currentOpenedHandleCount()
        let result = try await operation()
        let openedHandleCountAfter = try currentOpenedHandleCount()

        #expect(
            openedHandleCountBefore == openedHandleCountAfter, 
            "The num of resource handle opened before and after running the operation should be identical", 
            sourceLocation: sourceLocation
        )

        return result

    }


    func expectNoResHandleLeak<R>(
        sourceLocation: SourceLocation = #_sourceLocation,
        operation: () async throws -> sending R,
        preheat: () async throws -> Void
    ) async throws -> sending R {

        try await preheat()

        let openedHandleCountBefore = try currentOpenedHandleCount()
        let result = try await operation()
        let openedHandleCountAfter = try currentOpenedHandleCount()

        #expect(
            openedHandleCountBefore == openedHandleCountAfter, 
            "The num of resource handle opened before and after running the operation should be identical", 
            sourceLocation: sourceLocation
        )

        return result

    }


    func preheatWindowsSecurityDescriptor(forFileAt path: FilePath) {
        #if canImport(WinSDK)
        let handle = path.string.withCString(encodedAs: UTF16.self) { pathPtr in 
            CreateFileW(
                pathPtr, 
                DWORD(READ_ATTRIBUTES | READ_CONTROL), 
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE), 
                nil, 
                DWORD(OPEN_EXISTING), 
                DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS), 
                nil
            )
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            return
        }
        defer { CloseHandle(handle) }

        var securityDescriptorPtr = nil as PSECURITY_DESCRIPTOR?
        GetSecurityInfo(
            handle, 
            SE_FILE_OBJECT, 
            DWORD(OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION), 
            nil, nil, nil, nil, 
            &securityDescriptorPtr
        )
        guard let securityDescriptorPtr else { return }
        LocalFree(securityDescriptorPtr)
        #endif
    }

}




extension FileSystemTest {

    struct ExpectationCriterias: OptionSet {
            
        let rawValue: UInt64

        static let type: Self = .init(rawValue: 1 << 0)
        static let accessTime: Self = .init(rawValue: 1 << 1)
        static let modificationTime: Self = .init(rawValue: 1 << 2)
        static let creationTime: Self = .init(rawValue: 1 << 3)
        static let permission: Self = .init(rawValue: 1 << 4)
        static let attributes: Self = .init(rawValue: 1 << 5)
        static let size: Self = .init(rawValue: 1 << 6)
        static let contents: Self = .init(rawValue: 1 << 7)

        static let fileTimes: Self = [.accessTime, .modificationTime, .creationTime]

    }


    enum ItemExpectation {
        case file(path: FilePath, info: FileInfo, contents: Data?, excludedCriteria: ExpectationCriterias = [])
        case symlink(path: FilePath, info: FileInfo, target: FilePath, excludedCriteria: ExpectationCriterias = [])
        case directory(path: FilePath, info: FileInfo, excludedCriteria: ExpectationCriterias = [])

        var path: FilePath {
            switch self {
                case .file(let path, _, _, _): return path
                case .symlink(let path, _, _, _): return path
                case .directory(let path, _, _): return path
            }
        }

        var info: FileInfo {
            switch self {
                case .file(_, let info, _, _): return info
                case .symlink(_, let info, _, _): return info
                case .directory(_, let info, _): return info
            }
        }

        var excludedCriteria: ExpectationCriterias {
            switch self {
                case .file(_, _, _, let excludedCriteria): return excludedCriteria
                case .symlink(_, _, _, let excludedCriteria): return excludedCriteria
                case .directory(_, _, let excludedCriteria): return excludedCriteria
            }
        }

        func preconditionSelfValid() {
            switch self {
                case .file(_, let info, _, _): precondition(info.type == .regular)
                case .symlink(_, let info, _, _): precondition(info.type == .symlink)
                case .directory(_, let info, _): precondition(info.type == .directory)
            }
        }

        static func from(itemAt path: FilePath, followSymlink: Bool = false, excluding excludedCriteria: ExpectationCriterias = []) throws -> Self {
            let type = try FileInfo(fileAt: path, followSymLink: followSymlink).type
            switch type {
                case .regular:
                    let contents = try Data(contentsOf: .init(filePath: path.string))
                    return .file(path: path, info: try FileInfo(fileAt: path, followSymLink: true), contents: contents, excludedCriteria: excludedCriteria)
                case .symlink:
                    let targetPath = FilePath(stringLiteral: try FileManager.default.destinationOfSymbolicLink(atPath: path.string))
                    return .symlink(path: path, info: try FileInfo(fileAt: path, followSymLink: false), target: targetPath, excludedCriteria: excludedCriteria)
                case .directory:
                    return .directory(path: path, info: try FileInfo(fileAt: path, followSymLink: true), excludedCriteria: excludedCriteria)
                default:
                    fatalError("Unsupported file type \(type) at path \(path)")
            }
        }
    }


    enum FileStructureExpectation {
        case item(expectation: ItemExpectation, sourceLocation: SourceLocation = #_sourceLocation)
        case dir(expectation: ItemExpectation, contents: [FilePath.Component: FileStructureExpectation], sourceLocation: SourceLocation = #_sourceLocation)

        var expectation: ItemExpectation {
            switch self {
                case .item(let expectation, _): return expectation
                case .dir(let expectation, _, _): return expectation
            }
        }

        subscript(_ name: FilePath.Component) -> FileStructureExpectation {
            switch self {
                case .dir(_, let contents, _):
                    guard let subExpectation = contents[name] else {
                        fatalError("No such entry \(name) in expectation")
                    }
                    return subExpectation
                case .item:
                    fatalError("Cannot get sub-entry from a non-dir expectation")
            }
        }
    }


    func expectItemEquals(path1: FilePath, path2: FilePath, sourceLocation: SourceLocation = #_sourceLocation) throws {
        try expectItem(
            at: path1, 
            toMatch: try .from(itemAt: path2), 
            sourceLocation: sourceLocation
        )
    }


    func expectItem(
        at path: FilePath, 
        toMatch expectation: ItemExpectation, 
        followSymlink: Bool = false,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {

        expectation.preconditionSelfValid()
        
        #if canImport(Musl) || canImport(Glibc)
        let excludedCriteria = expectation.excludedCriteria.union(.creationTime)
        #else
        let excludedCriteria = expectation.excludedCriteria
        #endif 

        let info = try FileInfo(fileAt: path, followSymLink: followSymlink)

        let comment = "when matching item at \(try testRelativePath(of: path)) to item at \(try testRelativePath(of: expectation.path))" as Comment

        if !excludedCriteria.contains(.type) {
            #expect(info.type == expectation.info.type, comment, sourceLocation: sourceLocation)
        }
        if !excludedCriteria.contains(.accessTime) {
            #expect(info.times.lastAccess == expectation.info.times.lastAccess, comment, sourceLocation: sourceLocation)
        }
        if !excludedCriteria.contains(.modificationTime) {
            #expect(info.times.lastModification == expectation.info.times.lastModification, comment, sourceLocation: sourceLocation)
        }
        if !excludedCriteria.contains(.creationTime) {
            #expect(info.times.creation == expectation.info.times.creation, comment, sourceLocation: sourceLocation)
        }
        // TODO: add permission comparison for Windows
        #if !canImport(WinSDK)
        if !excludedCriteria.contains(.permission) {
            #expect(info.permissions == expectation.info.permissions, comment, sourceLocation: sourceLocation)
        }
        #endif 
        if !excludedCriteria.contains(.attributes) {
            #expect(info.attributes == expectation.info.attributes, comment, sourceLocation: sourceLocation)
            #expect(info.supportedAttributes == expectation.info.supportedAttributes, comment, sourceLocation: sourceLocation)
        }

        if info.type != .directory && !excludedCriteria.contains(.size) {   // size of directory will never be compared
            #expect(info.size == expectation.info.size, comment, sourceLocation: sourceLocation)
        }

        if !excludedCriteria.contains(.contents) {
            switch (info.type, expectation) {
                case (.regular, .file(_, _, let expectedContents, _)): 
                    let content1 = try Data(contentsOf: .init(fileURLWithPath: path.string))
                    #expect(content1 == expectedContents, comment, sourceLocation: sourceLocation)
                case (.symlink, .symlink(_, _, let expectedTarget, _)):
                    let target = try FileManager.default.destinationOfSymbolicLink(atPath: path.string)
                    #expect(target == expectedTarget.string, comment, sourceLocation: sourceLocation)
                default: 
                    break
            }
        }

    }

    
    func expectFileStructure(
        at path: FilePath, 
        toMatch structureExpectation: FileStructureExpectation
    ) throws {

        switch structureExpectation {
            case .item(let itemExpectation, let sourceLocation):
                try expectItem(at: path, toMatch: itemExpectation, sourceLocation: sourceLocation)
            case .dir(let itemExpectation, let expectedContents, let sourceLocation):
                try expectItem(at: path, toMatch: itemExpectation, sourceLocation: sourceLocation)
                let dirEntryCount = try FileManager.default.contentsOfDirectory(at: .init(filePath: path.string), includingPropertiesForKeys: nil).count
                #expect(dirEntryCount == expectedContents.count, sourceLocation: sourceLocation)
                for (name, subExpectation) in expectedContents {
                    let entryPath = path.appending(name)
                    try expectFileStructure(at: entryPath, toMatch: subExpectation)
                }
        }

    }


    private func testRelativePath(of path: FilePath, sourceLocation: SourceLocation = #_sourceLocation) throws -> FilePath {

        if path.isRelative { return path }

        try #require(
            path.starts(with: testDir), 
            "The path \(path) is not under the test directory, which can be unsafe", 
            sourceLocation: sourceLocation
        )

        return .init(root: nil, path.components.dropFirst(testDir.components.count))

    }

}