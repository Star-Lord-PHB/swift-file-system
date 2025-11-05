

// TODO: Make it conform to IteratorProtocol when non-copyable sequences in Swift are supported
public protocol DirectoryEntryIteratorProtocol: ~Copyable, ~Escapable {
    mutating func next() -> Result<DirectoryEntry, FileError>?
}



// TODO: Make it conform to Sequence when non-copyable sequences in Swift are supported
public protocol DirectoryEntrySequenceProtocol: ~Copyable, ~Escapable {
    // TODO: Migrate to associatedtype when non-copyable associated types in protocols are supported
    // associatedtype Iterator: DirectoryEntryIteratorProtocol & ~Escapable & ~Copyable
    typealias Iterator = any (DirectoryEntryIteratorProtocol & ~Escapable & ~Copyable)
    @_lifetime(borrow self)
    func makeIterator() -> Iterator
}



extension DirectoryEntrySequenceProtocol where Self: ~Copyable & ~Escapable {

    public func forEach<E: Error>(_ body: (Result<DirectoryEntry, FileError>) throws(E) -> Void) throws(E) {

        var iterator = makeIterator()
        while let entryResult = iterator.next() {
            try body(entryResult)
        }

    }


    public func map<T, E: Error>(_ transform: (Result<DirectoryEntry, FileError>) throws(E) -> T) throws(E) -> [T] {

        var results = [T]()
        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            results.append(try transform(entryResult))
        }

        return results

    }


    public func compactMap<T, E: Error>(_ transform: (Result<DirectoryEntry, FileError>) throws(E) -> T?) throws(E) -> [T] {

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
        _ nextPartialResult: (consuming T, Result<DirectoryEntry, FileError>) throws(E) -> T
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
        _ nextPartialResult: (inout T, Result<DirectoryEntry, FileError>) throws(E) -> Void
    ) throws(E) {

        var iterator = makeIterator()

        while let entryResult = iterator.next() {
            try nextPartialResult(&initialResult, entryResult)
        }

    }

}