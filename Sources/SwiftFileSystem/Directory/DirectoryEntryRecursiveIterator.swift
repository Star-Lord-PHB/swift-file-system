import SystemPackage
import FileSystemCore



public struct DirectoryEntryRecursiveIterator: DirectoryEntryIteratorRecursiveProtocol, ~Escapable, ~Copyable {

    private var enumerator: DirectoryEntryRecursiveEnumerator

    public var rootPath: FilePath { enumerator.rootPath }
    

    @_lifetime(immortal)
    public init(path: FilePath, options: FileOperationOptions.DirectoryTraversalOption = []) {
        self.enumerator = .init(path: path, options: options)
    }


    public mutating func next() -> DirectoryEntryRecursiveSequenceResult? {

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