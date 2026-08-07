import FileSystemCore
import struct SystemPackage.FilePath



/// Performs one recursive copy operation.
///
/// The handler owns the source and destination roots, so every item taking part in the copy is identified by a
/// single path relative to those roots. That relative path is also exactly what the error report uses, which is
/// why the copy layer speaks in relative paths and only the leaf helpers (metadata writes, handle opening,
/// ``InternalFS`` calls) take absolute ones. ``srcAbsolutePath(of:)`` and ``dstAbsolutePath(of:)`` are the only
/// places where the two are composed.
///
/// An instance performs a single copy; it is not reusable.
struct CopyItemHandler<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol> {

    /// The source root as given by the caller. Only used to describe the operation in the error report; the copy
    /// itself resolves against ``srcCopyRootPath``, which differs when `symlinkOption` is `.copyTarget`.
    let srcRootPath: FilePath
    let dstRootPath: FilePath

    /// The source root the copy actually reads from: ``srcRootPath``, or its resolved target when
    /// `symlinkOption` is `.copyTarget`. Assigned once at the beginning of ``perform()``.
    private var srcCopyRootPath: FilePath

    let options: FileOperationOptions.CopyItemOptions

    var errorCollector: RecursiveCopyErrorCollector

    private var _currentUser: PlatformIdentity? = nil

    var errorStrategy: ErrorStrategy { errorCollector.strategy }


    init(
        srcRootPath: FilePath,
        dstRootPath: FilePath,
        options: FileOperationOptions.CopyItemOptions = .init(),
        errorStrategy: ErrorStrategy = .abortOnError
    ) {
        self.srcRootPath = srcRootPath
        self.dstRootPath = dstRootPath
        self.srcCopyRootPath = srcRootPath
        self.options = options
        self.errorCollector = .init(srcRootPath: srcRootPath, dstRootPath: dstRootPath, strategy: errorStrategy)
    }


    /// The absolute source path of the item at `relativePath`.
    func srcAbsolutePath(of relativePath: FilePath) -> FilePath {
        assert(relativePath.isRelative, "relativePath must be relative")
        return srcCopyRootPath.appending(relativePath.components)
    }


    /// The absolute destination path of the item at `relativePath`.
    func dstAbsolutePath(of relativePath: FilePath) -> FilePath {
        assert(relativePath.isRelative, "relativePath must be relative")
        return dstRootPath.appending(relativePath.components)
    }


    mutating func getAndCacheCurrentUser() throws(LowLevelError) -> PlatformIdentity {
        if let user = _currentUser {
            return user
        }
        let user = try InternalPlatformAPI.currentIdentity()
        _currentUser = user
        return user
    }


    static func copyItem(
        at srcPath: FilePath,
        to dstPath: FilePath,
        options: FileOperationOptions.CopyItemOptions = .init(),
        errorStrategy: ErrorStrategy = .abortOnError
    ) throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.ReturnedError {
        var handler = Self(
            srcRootPath: srcPath,
            dstRootPath: dstPath,
            options: options,
            errorStrategy: errorStrategy
        )
        return try handler.perform()
    }

}



extension CopyItemHandler {

    mutating func perform() throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.ReturnedError {

        do throws(RecursiveCopyAbortError) {

            // resolve symlink first if needed
            if options.symlinkOption == .copyTarget {
                do {
                    srcCopyRootPath = try InternalFS.realpath(of: srcRootPath)
                } catch {
                    try errorCollector.handleErrorAndAbort(error, itemRelativePath: .init())
                }
            }

            try copyItemNoFollow(itemRelativePath: .init())

        } catch { /* Abort errors are not necessary to be handled */ }

        return try errorStrategy.reportError(errorCollector.report.value)

    }


    /// Copies the single item at `itemRelativePath`, dispatching on its type. Only ever called for the copy root.
    fileprivate mutating func copyItemNoFollow(
        itemRelativePath: FilePath
    ) throws(RecursiveCopyAbortError) {

        let srcAttrs: CachedCopySrcItemAttrs
        do {
            srcAttrs = try cacheItemAttrsForCopy(forItemAt: srcAbsolutePath(of: itemRelativePath))
        } catch {
            try errorCollector.handleErrorAndAbort(error, itemRelativePath: itemRelativePath)
        }
        let type = srcAttrs.type

        switch type {
            case .regular:
                do {
                    try copyFile(itemRelativePath: itemRelativePath, srcAttrs: srcAttrs)
                } catch {
                    try errorCollector.handleErrorAndAbort(error, itemRelativePath: itemRelativePath)
                }
            case .symlink:
                do {
                    try copySymlink(itemRelativePath: itemRelativePath, srcAttrs: srcAttrs)
                } catch {
                    try errorCollector.handleErrorAndAbort(error, itemRelativePath: itemRelativePath)
                }
            case .directory:
                try copyDirectoryRecursive(srcAttrs: srcAttrs)
            default:
                try errorCollector.handleErrorAndAbort(.init(kind: .unsupported), itemRelativePath: itemRelativePath)
        }

    }

}



extension CopyItemHandler {

    struct RecursiveCopyAbortError: Error {}


    struct RecursiveCopyErrorCollector {

        /// The report is only materialized once there is something to put in it, since
        /// ``RecursiveCopyErrorReport`` cannot represent an empty error list.
        enum LazyReport {
            case none
            case some(RecursiveCopyErrorReport)
            var value: RecursiveCopyErrorReport? {
                switch self {
                    case .none: return nil
                    case .some(let report): return report
                }
            }
        }

        let srcRootPath: FilePath
        let dstRootPath: FilePath
        let strategy: ErrorStrategy

        private(set) var report: LazyReport = .none
        private(set) var aborted: Bool = false

        init(srcRootPath: FilePath, dstRootPath: FilePath, strategy: ErrorStrategy) {
            self.srcRootPath = srcRootPath
            self.dstRootPath = dstRootPath
            self.strategy = strategy
        }

        private mutating func collect(_ error: RecursiveCopySingleItemError) {
            switch report {
                case .none:
                    report = .some(.init(srcRootPath: srcRootPath, dstRootPath: dstRootPath, firstError: error))
                case .some(var existing):
                    existing.append(error)
                    report = .some(existing)
            }
        }

        mutating func handleError(_ error: LowLevelError, itemRelativePath: FilePath) throws(RecursiveCopyAbortError)  {
            assert(aborted == false, "Should not handle further error after aborted")
            assert(itemRelativePath.isRelative, "itemRelativePath must be relative")
            let (collect, abort) = strategy.handleError(lowLevelError: error, itemRelativePath: itemRelativePath)
            if collect {
                self.collect(.init(itemRelativePath: itemRelativePath, code: error.systemCode, kind: error.kind))
            }
            if abort {
                aborted = true
                throw .init()
            }
        }

        mutating func handleErrorAndAbort(_ error: LowLevelError, itemRelativePath: FilePath) throws(RecursiveCopyAbortError) -> Never {
            assert(aborted == false, "Should not handle further error after aborted")
            defer { aborted = true }
            try handleError(error, itemRelativePath: itemRelativePath)
            throw .init()
        }

    }

}
