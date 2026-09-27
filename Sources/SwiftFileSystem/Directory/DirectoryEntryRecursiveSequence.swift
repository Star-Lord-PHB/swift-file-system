import SystemPackage
import FileSystemCore



/// A sequence for recursively traversing a directory and its subdirectories, yielding ``DirectoryEntryRecursiveSequenceElement`` values.
public struct DirectoryEntryRecursiveSequence: Sendable {

    public typealias Element = DirectoryEntryRecursiveSequenceElement

    /// The path of the directory to traverse.
    public let path: FilePath
    /// The options for directory traversal.
    public let options: FileOperationOptions.DirectoryTraversalOption


    public init(dirAt path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) {
        self.path = path
        self.options = options
    }


    public func makeIterator() -> Iterator {
        return .init(path: path, options: options)
    }

}



extension DirectoryEntryRecursiveSequence {

    /// The iterator for recursively traversing a directory and its subdirectories.
    public struct Iterator: ~Copyable {

        private var enumerator: DirectoryEntryRecursiveEnumerator

        private var skipDescendantsRequested: Bool = false
        private var skipCurrentDirRequested: Bool = false

        /// The path of the root directory being traversed.
        public var rootPath: FilePath { enumerator.rootPath }
        

        public init(path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) {
            self.enumerator = .init(path: path, options: options)
        }


        /// Skips the descendants of a newly meet directory.
        /// 
        /// If the current entry that is just emitted is a directory, this method will skip that directory 
        /// without emitting a ``DirectoryEntryRecursiveSequenceElement/leavingDir(_:_:)`` element. Otherwise, this 
        /// method has no effect
        public mutating func skipDescendants() {
            if !enumerator.currentDirRelativePath.isEmpty {
                skipDescendantsRequested = true
            }
        }


        /// Leaves the current directory early and emits a ``DirectoryEntryRecursiveSequenceElement/leavingDir(_:_:)``
        /// element.
        public mutating func skipCurrentDir() {
            skipCurrentDirRequested = true
        }


        /// Emit the next element.
        public mutating func next() throws(PlatformError) -> Element? {

            defer { 
                skipDescendantsRequested = false
                skipCurrentDirRequested = false
            }

            return try catchLowLevelError(operation: .readDirectory(rootPath)) { () throws(LowLevelError) in

                return try enumerator.next(
                    skipCurrentDir: skipCurrentDirRequested, 
                    skipDescendants: skipDescendantsRequested
                )
                .map { element in

                    return switch element {
                        case .entry(let entry): 
                            .entry(entry)
                        case .entryError(let path, let error): 
                            .entryError(path, .init(lowLevelError: error, operation: .readDirectory(path.removingLastComponent())))
                        case .subTreeError(let path, let error): 
                            .subTreeError(path, .init(lowLevelError: error, operation: .readDirectory(path)))
                        case .leavingDir(let path, .some(let error)): 
                            .leavingDir(path, .init(lowLevelError: error, operation: .readDirectory(path)))
                        case .leavingDir(let path, .none):
                            .leavingDir(path, nil)
                    }

                }

            }

        }

    }

}



extension DirectoryEntryRecursiveSequence {

    public func forEach<E: Error>(_ body: (Element) throws(E) -> Void) throws {

        var iterator = makeIterator()
        while let entryResult = try iterator.next() {
            try body(entryResult)
        }

    }


    public func map<T, E: Error>(_ transform: (Element) throws(E) -> T) throws -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = try iterator.next() {
            results.append(try transform(entryResult))
        }

        return results

    }


    public func compactMap<T, E: Error>(_ transform: (Element) throws(E) -> T?) throws -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = try iterator.next() {
            if let transformed = try transform(entryResult) {
                results.append(transformed)
            }
        }

        return results

    }


    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, Element) throws(E) -> T
    ) throws -> T {

        var result = initialResult
        var iterator = makeIterator()

        while let entryResult = try iterator.next() {
            result = try nextPartialResult(result, entryResult)
        }

        return result

    }


    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: inout T, 
        _ nextPartialResult: (inout T, Element) throws(E) -> Void
    ) throws {

        var iterator = makeIterator()

        while let entryResult = try iterator.next() {
            try nextPartialResult(&initialResult, entryResult)
        }

    }

}
