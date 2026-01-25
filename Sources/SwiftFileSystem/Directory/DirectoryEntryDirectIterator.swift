import SystemPackage
import FileSystemCore



extension DirectoryEntryIterator {

    public struct DirectoryEntryDirectIterator: DirectoryEntryIteratorProtocol, ~Copyable {

        private var enumerator: DirectoryEntryDirectEnumerator

        public var rootPath: FilePath { enumerator.rootPath }
        public var ended: Bool { enumerator.ended }


        init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) throws(PlatformError) {
            do {
                self.enumerator = try .init(unsafeSystemHandle: unsafeSystemHandle, path: path)
            } catch {
                throw PlatformError(systemError: error, operation: .readDirectory(path))
            }
            
        }


        public mutating func next() -> DirectoryEntrySequenceResult? {
            do {
                return try catchSystemError(
                    operation: .readDirectory(rootPath)
                ) { () throws(SystemError) in
                    while let element = try enumerator.next() {
                        switch element {
                            case .entry(let entry): 
                                return .success(.entry(entry))
                            case .entryError(let path, let error): 
                                return .success(.entryError(path, .init(systemError: error, operation: .readDirectory(rootPath))))
                        }
                    }
                    return nil
                }
            } catch {
                return .failure(error)
            }
        }

    }

}