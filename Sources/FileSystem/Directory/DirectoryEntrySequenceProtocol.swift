import SystemPackage


public enum DirectoryEntrySequenceElement: Sendable {
    case entry(DirectoryEntry)
    case entryError(FilePath, FileError)

    public var path: FilePath {
        switch self {
            case .entry(let entry):         entry.path
            case .entryError(let path, _):  path
        }
    }

    public var name: String {
        path.lastComponent!.string
    }
}


public typealias DirectoryEntrySequenceResult = Result<DirectoryEntrySequenceElement, FileError>



// TODO: Make it conform to IteratorProtocol when non-copyable sequences in Swift are supported
public protocol DirectoryEntryIteratorProtocol: ~Copyable {
    mutating func next() -> DirectoryEntrySequenceResult?
}



// TODO: Make it conform to Sequence when non-copyable sequences in Swift are supported
public protocol DirectoryEntrySequenceProtocol: ~Copyable, ~Escapable {
    // TODO: Migrate to associatedtype when non-copyable associated types in protocols are supported
    // associatedtype Iterator: DirectoryEntryIteratorProtocol & ~Escapable & ~Copyable
    typealias Iterator = any (DirectoryEntryIteratorProtocol & ~Copyable)
    @_lifetime(borrow self)
    func makeIterator() -> Iterator
}



extension DirectoryEntrySequenceProtocol where Self: ~Copyable & ~Escapable {

    public func forEach<E: Error>(_ body: (DirectoryEntrySequenceResult) throws(E) -> Void) throws(E) {

        var iterator = makeIterator()
        while let entryResult = iterator.next() {
            try body(entryResult)
        }

    }


    public func map<T, E: Error>(_ transform: (DirectoryEntrySequenceResult) throws(E) -> T) throws(E) -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            results.append(try transform(entryResult))
        }

        return results

    }


    public func compactMap<T, E: Error>(_ transform: (DirectoryEntrySequenceResult) throws(E) -> T?) throws(E) -> [T] {

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
        _ nextPartialResult: (consuming T, DirectoryEntrySequenceResult) throws(E) -> T
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
        _ nextPartialResult: (inout T, DirectoryEntrySequenceResult) throws(E) -> Void
    ) throws(E) {

        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            try nextPartialResult(&initialResult, entryResult)
        }

    }

}