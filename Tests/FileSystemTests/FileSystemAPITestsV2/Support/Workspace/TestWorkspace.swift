import Foundation
import SystemPackage
import Testing

/// An isolated filesystem workspace owned by one test instance.
///
/// Test suites should hold this type as a stored property instead of inheriting
/// filesystem helpers from a common base class.
extension FileSystemTestSupport {

    final class Workspace {

        static let parentDirectory = FilePath(URL.temporaryDirectory.path)
            .appending("swift-file-system-tests-v2")

        #if KEEP_FILE_SYSTEM_TEST_WORKSPACES
            static let defaultKeepArtifacts = true
        #else
            static let defaultKeepArtifacts = false
        #endif

        let root: FilePath

        private var hasCleanedUp = false

        init(
            parentDirectory: FilePath = Workspace.parentDirectory,
            keepArtifacts: Bool = Workspace.defaultKeepArtifacts
        ) throws {
            let test = try #require(Test.current, "Workspace must be created while a test is running")
            let testName = Self.sanitizedPathComponent(from: test.name)
            root = try Self.makeUniqueRoot(
                in: parentDirectory,
                testName: testName
            )
            self.keepArtifacts = keepArtifacts
        }

        deinit {
            try? cleanup()
        }

        private let keepArtifacts: Bool

        /// Resolves a relative test path without allowing lexical traversal outside
        /// the workspace.
        func path(_ relativePath: FilePath) -> FilePath {
            precondition(relativePath.isRelative, "Test workspace paths must be relative")
            guard let resolved = root.lexicallyResolving(relativePath) else {
                preconditionFailure("Test workspace path escapes its root: \(relativePath)")
            }
            return resolved
        }

        func path(_ relativePath: String) -> FilePath {
            path(FilePath(relativePath))
        }

        /// Returns a diagnostic path relative to the workspace when possible.
        func diagnosticPath(for path: FilePath) -> FilePath {
            guard !path.isRelative, path.starts(with: root) else { return path }
            return FilePath(root: nil, path.components.dropFirst(root.components.count))
        }

        /// Removes the workspace. Calling this method more than once is harmless.
        func cleanup() throws {
            guard !hasCleanedUp else { return }

            if !keepArtifacts, FileManager.default.fileExists(atPath: root.string) {
                try FileManager.default.removeItem(at: URL(filePath: root.string))
            }
            hasCleanedUp = true
        }

        private static func sanitizedPathComponent(from name: String) -> String {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
            let scalars = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
            let sanitized = String(scalars).prefix(48)
            return sanitized.isEmpty ? "test" : String(sanitized)
        }

        private static func makeUniqueRoot(
            in parentDirectory: FilePath,
            testName: String
        ) throws -> FilePath {
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: URL(filePath: parentDirectory.string),
                withIntermediateDirectories: true
            )

            let processID = ProcessInfo.processInfo.processIdentifier
            while true {
                let testID = idSource.next()
                let candidate = parentDirectory.appending("\(testName)-p\(processID)-t\(testID)")

                // The counter guarantees uniqueness inside this process and the PID
                // separates concurrently running test processes. Checking for an
                // existing path also handles a stale directory after PID reuse.
                guard !fileManager.fileExists(atPath: candidate.string) else { continue }

                try fileManager.createDirectory(
                    at: URL(filePath: candidate.string),
                    withIntermediateDirectories: false
                )
                return candidate
            }
        }

        private static let idSource = AtomicIDSource()

    }

}

extension FileSystemTestSupport.Workspace {

    private final class AtomicIDSource: @unchecked Sendable {

        private let lock = NSLock()
        private var value = UInt64(0)

        func next() -> UInt64 {
            lock.withLock {
                value += 1
                return value
            }
        }

    }

}
