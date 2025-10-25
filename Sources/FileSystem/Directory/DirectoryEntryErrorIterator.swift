import SystemPackage
import Foundation



extension DirectoryEntryIterator {

    public struct DirectoryEntryErrorIterator: DirectoryEntryIteratorProtocol {

        public let error: FileError
        public private(set) var ended: Bool = false


        init(error: FileError) {
            self.error = error
        }


        public mutating func next() -> Result<DirectoryEntry, FileError>? {
            guard !ended else { return nil }
            ended = true
            return .failure(error)
        }

    }

}