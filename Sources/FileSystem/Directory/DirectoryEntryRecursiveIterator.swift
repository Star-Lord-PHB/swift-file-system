import SystemPackage

import PlatformCLib
import CFileSystem



extension DirectoryEntryIterator {

    public struct DirectoryEntryRecursiveIterator: DirectoryEntryIteratorProtocol, ~Copyable {

        var enumerator: DirectoryEntryRecursiveEnumerator

        public var rootPath: FilePath { enumerator.rootPath }
        

        public init(path: FilePath) throws(FileError) {
            self.enumerator = try catchSystemError(operationDescription: .readingDirEntries(at: path)) { () throws(SystemError) in
                try .init(path: path)
            }
        }


        public mutating func next() -> DirectoryEntrySequenceResult? {
            do {
                return try catchSystemError(
                    operationDescription: .readingDirEntries(at: rootPath)
                ) { () throws(SystemError) in
                    while let element = try enumerator.next() {
                        switch element {
                            case .entry(let entry): 
                                return .success(.entry(entry))
                            case .entryError(let path, let error): 
                                return .success(.entryError(path, .init(systemError: error, operationDescription: .readingDirEntries(at: rootPath))))
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