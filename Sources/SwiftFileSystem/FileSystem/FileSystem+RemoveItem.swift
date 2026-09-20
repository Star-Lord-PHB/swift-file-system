import SystemPackage
import FileSystemCore



extension FileSystem {

    public func removeItem(at path: FilePath) throws(PlatformError) {

        var handler = RecursiveRemoveItemHandler(path: path)
        while handler.next() == .paused {}

        if let firstError = handler.firstError {
            throw firstError
        }

    }

}



package struct RecursiveRemoveItemHandler: ~Copyable {

    package enum StepResult: Equatable, Sendable {
        case completed, paused
    }


    package let rootPath: FilePath
    var enumerator: DirectoryEntryRecursiveEnumerator? = nil
    var notDeletableDepth: Int = -1
    var currentDepth: Int = 0
    package let cancellationToken: CancellationToken
    package private(set) var firstError: PlatformError? = nil
    package private(set) var completed: Bool = false

    package init(path: FilePath, cancellationToken: CancellationToken = .init()) {
        self.rootPath = path
        self.cancellationToken = cancellationToken
    }


    package mutating func next() -> StepResult {

        defer {
            precondition(notDeletableDepth <= currentDepth, "notDeletableDepth should never be greater than currentDepth") 
        }

        guard !completed else { return .completed }

        if cancellationToken.isCancelled {
            completed = true
            firstError = .init(error: firstError ?? CancellationError(), kind: .cancelled, operation: .remove(rootPath))
            return .completed
        }

        do throws(PlatformError) {

            if enumerator == nil {

                do {
                    try InternalFS.remove(itemAt: rootPath)
                    completed = true
                    return .completed
                } catch let error where error.kind != .notEmptyDirectory {
                    completed = true
                    throw PlatformError(lowLevelError: error, operation: .remove(rootPath))
                } catch {
                    // do nothing
                }
                
                self.enumerator = DirectoryEntryRecursiveEnumerator(path: rootPath)

            }

            let enumerationResult = Result { () throws(LowLevelError) in 
                try enumerator!.next() 
            }

            let enumerationElement: DirectoryEntryRecursiveEnumerator.Element

            switch enumerationResult {
                case .failure(let err):
                    completed = true
                    throw .init(lowLevelError: err, operation: .remove(rootPath))
                case .success(.none):
                    completed = true
                    if notDeletableDepth < 0 {
                        try rmdir(at: rootPath, enumerationError: nil)
                    }
                    return .completed
                case .success(.some(let e)):
                    enumerationElement = e
            }

            switch enumerationElement {
                case .entry(let entry) where entry.type == .directory:
                    currentDepth += 1
                case .entry(let entry):
                    #if canImport(WinSDK)
                    // On Windows, the item may be a symlink to a directory, which cannot be removed by DeleteFileW
                    try remove(itemAt: rootPath.appending(entry.path.components), enumerationError: nil)
                    #else
                    try unlink(fileAt: rootPath.appending(entry.path.components), enumerationError: nil)
                    #endif
                case .entryError(let path, let error):
                    try remove(itemAt: rootPath.appending(path.components), enumerationError: error)
                case .leavingDir(let path, let enumerationErr), .subTreeError(let path, let enumerationErr as LowLevelError?):
                    currentDepth -= 1
                    defer {
                        notDeletableDepth = min(notDeletableDepth, currentDepth)
                    }
                    if currentDepth + 1 > notDeletableDepth {
                        try rmdir(at: rootPath.appending(path.components), enumerationError: enumerationErr)
                    }
            }

        } catch {
            if firstError == nil {
                firstError = error
            }
        }

        return completed ? .completed : .paused

    }


    fileprivate mutating func unlink(fileAt path: FilePath, enumerationError: LowLevelError?) throws(PlatformError) {
        do {
            try InternalFS.unlink(fileAt: path)
        } catch let error where error.kind == .notFound {
            // do nothing
        } catch {
            notDeletableDepth = currentDepth
            throw .init(lowLevelError: enumerationError ?? error, operation: .remove(path))
        }
    }


    fileprivate mutating func rmdir(at path: FilePath, enumerationError: LowLevelError?) throws(PlatformError) {
        do {
            try InternalFS.rmdir(at: path)
        } catch let error where error.kind == .notFound {
            // do nothing
        } catch {
            notDeletableDepth = currentDepth
            throw .init(lowLevelError: enumerationError ?? error, operation: .remove(path))
        }
    }


    fileprivate mutating func remove(itemAt path: FilePath, enumerationError: LowLevelError?) throws(PlatformError) {
        do {
            try InternalFS.remove(itemAt: path)
        } catch let error where error.kind == .notFound {
            // do nothing
        } catch {
            notDeletableDepth = currentDepth
            throw .init(lowLevelError: enumerationError ?? error, operation: .remove(path))
        }
    }

}
