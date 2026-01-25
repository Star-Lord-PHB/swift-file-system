import FileSystemCore


extension DirectoryEntryIterator {

    public struct DirectoryEntryErrorIterator: DirectoryEntryIteratorProtocol {

        public let error: PlatformError
        public private(set) var ended: Bool = false


        init(error: PlatformError) {
            self.error = error
        }


        public mutating func next() -> DirectoryEntrySequenceResult? {
            guard !ended else { return nil }
            ended = true
            return .failure(error)
        }

    }

}