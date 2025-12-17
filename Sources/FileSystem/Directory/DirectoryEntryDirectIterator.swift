import SystemPackage

import PlatformCLib
import CFileSystem



extension DirectoryEntryIterator {

    public struct DirectoryEntryDirectIterator: DirectoryEntryIteratorProtocol, ~Copyable {

        private var enumerator: DirectoryEntryDirectEnumerator

        public var rootPath: FilePath { enumerator.rootPath }
        public var ended: Bool { enumerator.ended }


        init(unsafeSystemHandle: consuming UnsafeSystemHandle, path: FilePath) throws(FileError) {
            do {
                self.enumerator = try .init(unsafeSystemHandle: unsafeSystemHandle, path: path)
            } catch {
                throw FileError(systemError: error, operationDescription: .readingDirEntries(at: path))
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