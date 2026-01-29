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



public typealias DirectoryEntryRecursiveSequenceResult = Result<DirectoryEntryRecursiveSequenceElement, PlatformError>
public typealias DirectoryEntryDirectSequenceResult = Result<DirectoryEntry, PlatformError>



// TODO: Make it conform to IteratorProtocol when non-copyable sequences in Swift are supported
public protocol DirectoryEntryIteratorRecursiveProtocol: ~Escapable, ~Copyable {
    mutating func next() -> DirectoryEntryRecursiveSequenceResult?
}


public protocol DirectoryEntryDirectIteratorProtocol: ~Escapable, ~Copyable {
    mutating func next() -> DirectoryEntryDirectSequenceResult?
}



// TODO: Make it conform to Sequence when non-copyable sequences in Swift are supported
public protocol DirectoryEntryRecursiveSequenceProtocol: ~Copyable, ~Escapable {
    // TODO: Migrate to associatedtype when non-copyable associated types in protocols are supported
    // associatedtype Iterator: DirectoryEntryIteratorProtocol & ~Escapable & ~Copyable
    typealias Iterator = any (DirectoryEntryIteratorRecursiveProtocol & ~Escapable & ~Copyable)
    @_lifetime(borrow self)
    func makeIterator() -> Iterator
}



public protocol DirectoryEntryDirectSequenceProtocol: ~Copyable, ~Escapable {
    // TODO: Migrate to associatedtype when non-copyable associated types in protocols are supported
    // associatedtype Iterator: DirectoryEntryIteratorProtocol & ~Escapable & ~Copyable
    typealias Iterator = any (DirectoryEntryDirectIteratorProtocol & ~Escapable & ~Copyable)
    @_lifetime(borrow self)
    func makeIterator() -> Iterator
}



extension DirectoryEntryRecursiveSequenceProtocol where Self: ~Copyable & ~Escapable {

    public func forEach<E: Error>(_ body: (DirectoryEntryRecursiveSequenceResult) throws(E) -> Void) throws(E) {

        var iterator = makeIterator()
        while let entryResult = iterator.next() {
            try body(entryResult)
        }

    }


    public func map<T, E: Error>(_ transform: (DirectoryEntryRecursiveSequenceResult) throws(E) -> T) throws(E) -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            results.append(try transform(entryResult))
        }

        return results

    }


    public func compactMap<T, E: Error>(_ transform: (DirectoryEntryRecursiveSequenceResult) throws(E) -> T?) throws(E) -> [T] {

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
        _ nextPartialResult: (consuming T, DirectoryEntryRecursiveSequenceResult) throws(E) -> T
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
        _ nextPartialResult: (inout T, DirectoryEntryRecursiveSequenceResult) throws(E) -> Void
    ) throws(E) {

        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            try nextPartialResult(&initialResult, entryResult)
        }

    }

}



extension DirectoryEntryDirectSequenceProtocol where Self: ~Copyable & ~Escapable {

    public func forEach<E: Error>(_ body: (DirectoryEntryDirectSequenceResult) throws(E) -> Void) throws(E) {

        var iterator = makeIterator()
        while let entryResult = iterator.next() {
            try body(entryResult)
        }

    }


    public func map<T, E: Error>(_ transform: (DirectoryEntryDirectSequenceResult) throws(E) -> T) throws(E) -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            results.append(try transform(entryResult))
        }

        return results

    }


    public func compactMap<T, E: Error>(_ transform: (DirectoryEntryDirectSequenceResult) throws(E) -> T?) throws(E) -> [T] {

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
        _ nextPartialResult: (consuming T, DirectoryEntryDirectSequenceResult) throws(E) -> T
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
        _ nextPartialResult: (inout T, DirectoryEntryDirectSequenceResult) throws(E) -> Void
    ) throws(E) {

        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            try nextPartialResult(&initialResult, entryResult)
        }

    }

}