import SystemPackage
import FileSystemCore



public enum DirectoryEntryRecursiveSequenceElement: Sendable {
    case entry(DirectoryEntry)
    case leavingDir(FilePath, PlatformError?)
    case entryError(FilePath, PlatformError)
    case subTreeError(FilePath, PlatformError)

    public var path: FilePath {
        switch self {
            case .entry(let entry):          entry.path
            case .leavingDir(let path, _):   path
            case .entryError(let path, _):   path
            case .subTreeError(let path, _): path
        }
    }

    public var name: FilePath.Component { path.lastComponent! }

    public var error: PlatformError? {
        switch self {
            case .entry:                     return nil
            case .leavingDir(_, let err):    return err
            case .entryError(_, let err):    return err
            case .subTreeError(_, let err):  return err
        }
    }
}



public struct DirectoryEntryRecursiveSequence: Sendable {

    public typealias Element = Result<DirectoryEntryRecursiveSequenceElement, PlatformError>

    public let path: FilePath
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

    public struct Iterator: ~Copyable {

        private var enumerator: DirectoryEntryRecursiveEnumerator

        public var rootPath: FilePath { enumerator.rootPath }
        

        public init(path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) {
            self.enumerator = .init(path: path, options: options)
        }


        public mutating func next() -> Element? {

            do {

                return try catchLowLevelError(operation: .readDirectory(rootPath)) { () throws(LowLevelError) in

                    return try enumerator.next().map { element in

                        let element = switch element {
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
                        } as DirectoryEntryRecursiveSequenceElement

                        return .success(element)

                    }

                }

            } catch {
                return .failure(error)
            }

        }

    }

}



extension DirectoryEntryRecursiveSequence {

    public func forEach<E: Error>(_ body: (Element) throws(E) -> Void) throws(E) {

        var iterator = makeIterator()
        while let entryResult = iterator.next() {
            try body(entryResult)
        }

    }


    public func map<T, E: Error>(_ transform: (Element) throws(E) -> T) throws(E) -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            results.append(try transform(entryResult))
        }

        return results

    }


    public func compactMap<T, E: Error>(_ transform: (Element) throws(E) -> T?) throws(E) -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            if let transformed = try transform(entryResult) {
                results.append(transformed)
            }
        }

        return results

    }


    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T, 
        _ nextPartialResult: (consuming T, Element) throws(E) -> T
    ) throws(E) -> T {

        var result = initialResult
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            result = try nextPartialResult(result, entryResult)
        }

        return result

    }


    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: inout T, 
        _ nextPartialResult: (inout T, Element) throws(E) -> Void
    ) throws(E) {

        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            try nextPartialResult(&initialResult, entryResult)
        }

    }

}
