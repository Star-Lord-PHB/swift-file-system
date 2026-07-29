import SystemPackage
import FileSystemCore



public struct DirectoryEntryDirectIterator: DirectoryEntryDirectIteratorProtocol, ~Escapable, ~Copyable {

    private enum State: ~Copyable, ~Escapable {

        case ready(UnsafeUnownedSystemHandle, FilePath, FileOperationOptions.DirectoryTraversalOption)
        case opened(DirectoryEntryDirectEnumerator)

        mutating func next() throws(LowLevelError) -> DirectoryEntry? {
            switch consume self {
                case .ready(let handle, let path, let options):
                    do {
                        self = .opened(try .init(unsafeSystemHandle: handle.duplicate(), path: path, options: options))
                    } catch {
                        self = .ready(handle, path, options)
                        throw error
                    }
                case let s: 
                    self = s
            }
            switch consume self {
                case .opened(var enumerator):
                    do {
                        let entry = try enumerator.next()
                        self = .opened(enumerator)
                        return entry
                    } catch {
                        self = .opened(enumerator)
                        throw error
                    }
                default: 
                    fatalError("Should not reach here")
            }
        }

    }

    private var state: State


    public var rootPath: FilePath {
        switch state {
            case .ready(_, let path, _): path
            case .opened(let stream): stream.rootPath
        }
    }

    public var ended: Bool {
        switch state {
            case .ready:         false
            case .opened(let e): e.ended
        }
    }


    @_lifetime(copy unsafeSystemHandle)
    init(
        unsafeSystemHandle: UnsafeUnownedSystemHandle, 
        path: FilePath, 
        options: FileOperationOptions.DirectoryTraversalOption = []
    ) {
        self.state = .ready(unsafeSystemHandle, path, options)
    }


    public mutating func next() -> DirectoryEntryDirectSequenceResult? {
        do {
            return try state.next().map { .success($0) }
        } catch {
            return .failure(.init(lowLevelError: error, operation: .readDirectory(rootPath)))
        }
    }

}