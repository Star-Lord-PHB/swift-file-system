import SystemPackage
import FileSystemCore



extension DirectoryEntryIterator {

    public struct DirectoryEntryRecursiveIterator: DirectoryEntryIteratorProtocol, ~Copyable {

        var enumerator: DirectoryEntryRecursiveEnumerator

        public var rootPath: FilePath { enumerator.rootPath }
        

        public init(path: FilePath) throws(PlatformError) {
            self.enumerator = try catchSystemError(operation: .readDirectory(path)) { () throws(SystemError) in
                try .init(path: path)
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
                            case .leavingDir(_): 
                                continue
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