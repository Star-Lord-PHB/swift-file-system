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
package struct CopyItemHandler<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>: ~Copyable {

    /// The source root as given by the caller. Only used to describe the operation in the error report; the copy
    /// itself resolves against ``srcCopyRootPath``, which differs when `symlinkOption` is `.copyTarget`.
    package let srcRootPath: FilePath
    package let dstRootPath: FilePath

    /// The source root the copy actually reads from: ``srcRootPath``, or its resolved target when
    /// `symlinkOption` is `.copyTarget`. Assigned once by the first ``copyStep()``.
    private var srcCopyRootPath: FilePath

    package let options: FileOperationOptions.CopyItemOptions

    package let cancellationToken: CancellationToken

    var errorCollector: RecursiveCopyErrorCollector

    private var _currentUser: PlatformIdentity? = nil

    var state: State? = .ready

    var fileContentCopyBuffer: ByteBuffer?

    package var errorStrategy: ErrorStrategy { errorCollector.strategy }

    /// Returns true if the copy operation was truly cancelled (i.e. the cancellation request 
    /// was actually responded)
    package var operationCancelled: Bool {
        switch self.state {
            case .ended(cancelled: true): true
            default: false
        }
    }


    package init(
        srcRootPath: FilePath,
        dstRootPath: FilePath,
        options: FileOperationOptions.CopyItemOptions = .init(),
        cancellationToken: CancellationToken = .init(),
        errorStrategy: ErrorStrategy = .collectAndThrow
    ) {
        self.srcRootPath = srcRootPath
        self.dstRootPath = dstRootPath
        self.srcCopyRootPath = srcRootPath
        self.options = options
        self.cancellationToken = cancellationToken
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
        errorStrategy: ErrorStrategy = .collectAndThrow
    ) throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.Returned {
        var handler = Self(
            srcRootPath: srcPath,
            dstRootPath: dstPath,
            options: options,
            errorStrategy: errorStrategy
        )
        return try handler.perform()
    }


    func checkCancellationRequest() throws(RecursiveCopyAbortError) {
        if cancellationToken.isCancelled {
            throw .cancelled
        }
    }

}



extension CopyItemHandler {

    package mutating func perform() throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.Returned {
        while copyStep() == .paused {}
        return try reportResult()
    }


    package mutating func copyStep() -> StepResult {

        defer {
            switch self.state?.case {
                case .copying, .ended: 
                    break
                case let s: 
                    preconditionFailure("Invalid state after copy step: \(String(describing: s))")
            }
        }

        do throws(RecursiveCopyAbortError) {
            return try _copyStep()
        } catch {
            abortCleanup(error)
        }

        return .completed

    }


    package func reportResult() throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.Returned {

        switch self.state {
            case .ended: break
            default: preconditionFailure("Cannot report result before copy is completed or cancelled")
        }

        return try errorStrategy.reportResult(.init(
            srcRootPath: srcRootPath, 
            dstRootPath: dstRootPath, 
            itemErrors: errorCollector.errors.value, 
            operationCancelled: operationCancelled
        ))

    }


    fileprivate mutating func abortCleanup(_ abortError: RecursiveCopyAbortError) {
        switch self.state.take() {
            case .copying(_, .some):
                preconditionFailure("File copy context not cleaned up")
            case .copying(.some, _):
                preconditionFailure("Directory copy context not cleaned up")
            default:
                break
        }
        self.state = switch abortError {
            case .errorAborted: .ended(cancelled: false)
            case .cancelled: .ended(cancelled: true)
        }
    }


    fileprivate mutating func _copyStep() throws(RecursiveCopyAbortError) -> StepResult {

        switch self.state.take() {

            case .ready:
                self.state = .copying()
                try checkCancellationRequest()
                if options.symlinkOption == .copyTarget {
                    do {
                        srcCopyRootPath = try InternalFS.realpath(of: srcRootPath)
                    } catch {
                        try errorCollector.handleErrorAndAbort(error, operation: .getSrcMetadata)
                    }
                }
                guard let srcAttrs = try cacheItemAttrsForCopy(forItemAt: .init()) else {
                    try errorCollector.abort()
                }

                let type = srcAttrs.type

                switch type {
                    case .regular: 
                        try startCopyFile(itemRelativePath: .init(), srcAttrs: srcAttrs)
                    case .directory: 
                        try startCopyDirectoryRecursive(srcAttrs: srcAttrs)
                    case .symlink:
                        try copySymlink(itemRelativePath: .init(), srcAttrs: srcAttrs)
                    default: 
                        try errorCollector.handleErrorAndAbort(.init(kind: .unsupported), operation: .copyContents)
                }

            case .copying(.some(let dirCopyContext), let fileCopyContext):
                self.state = .copying(dirCopyContext: dirCopyContext, fileCopyContext: fileCopyContext)
                try copyDirectoryRecursiveStep()

            case .copying(.none, .some(let fileCopyContext)):
                self.state = .copying(dirCopyContext: nil, fileCopyContext: fileCopyContext)
                try copyFileStep()

            case .copying(.none, .none):
                self.state = .ended()

            case .ended(let cancelled):
                self.state = .ended(cancelled: cancelled)

            
            case .none: 
                preconditionFailure("Unreachable")

        }

        switch self.state.take() {
            case .ended(let cancelled):
                self.state = .ended(cancelled: cancelled)
                return .completed
            case .copying(.none, .none):
                self.state = .ended()
                return .completed
            case let state: 
                self.state = state
                return .paused
        }

    }

}



extension CopyItemHandler {

    package enum StepResult {
        case paused, completed
    }


    enum State: ~Copyable {
        case ready
        case copying(dirCopyContext: CopyDirContext? = nil, fileCopyContext: CopyFileContentContext? = nil)
        case ended(cancelled: Bool = false)

        var `case`: Case {
            switch self {
                case .ready: .ready
                case .copying: .copying
                case .ended: .ended
            }
        }

        enum Case: Equatable {
            case ready, copying, ended
        }

    }


    enum RecursiveCopyAbortError: Error {
        case errorAborted
        case cancelled
    }


    struct RecursiveCopyErrorCollector {

        /// The report is only materialized once there is something to put in it, since
        /// ``RecursiveCopyResult.NonEmptyItemErrorList`` cannot represent an empty error list.
        enum LazyErrors {
            case none
            case some(RecursiveCopyResult.NonEmptyItemErrorList)
            var value: RecursiveCopyResult.NonEmptyItemErrorList? {
                switch self {
                    case .none: return nil
                    case .some(let errors): return errors
                }
            }
        }

        let srcRootPath: FilePath
        let dstRootPath: FilePath
        let strategy: ErrorStrategy

        var currentItemRelativePath: FilePath = .init(root: nil) {
            didSet { assert(currentItemRelativePath.isRelative, "currentItemRelativePath must be relative") }
        }
        private(set) var errors: LazyErrors = .none
        private(set) var aborted: Bool = false
        

        init(srcRootPath: FilePath, dstRootPath: FilePath, strategy: ErrorStrategy) {
            self.srcRootPath = srcRootPath
            self.dstRootPath = dstRootPath
            self.strategy = strategy
        }


        private mutating func collect(_ error: RecursiveCopyResult.SingleItemError) {
            switch errors {
                case .none:
                    errors = .some([error])
                case .some(var existing):
                    existing.append(error)
                    errors = .some(existing)
            }
        }


        mutating func handleError(
            _ error: LowLevelError, 
            operation: RecursiveCopyResult.ItemOperation
        ) throws(RecursiveCopyAbortError) {
            assert(aborted == false, "Should not handle further error after aborted")
            let error = RecursiveCopyResult.SingleItemError(
                itemRelativePath: currentItemRelativePath, operation: operation, code: error.systemCode, kind: error.kind
            )
            let (collect, abort) = strategy.handleError(error)
            if collect {
                self.collect(error)
            }
            if abort {
                aborted = true
                throw .errorAborted
            }
        }


        mutating func handleErrorAndAbort(
            _ error: LowLevelError,
            operation: RecursiveCopyResult.ItemOperation
        ) throws(RecursiveCopyAbortError) -> Never {
            assert(aborted == false, "Should not handle further error after aborted")
            defer { aborted = true }
            try handleError(error, operation: operation)
            throw .errorAborted
        }


        /// Aborts without registering a new item error: for use where the error has already been
        /// reported through ``handleError(_:operation:)`` but the copy cannot continue regardless of
        /// what the strategy decided.
        mutating func abort() throws(RecursiveCopyAbortError) -> Never {
            assert(aborted == false, "Should not abort after aborted")
            aborted = true
            throw .errorAborted
        }


        mutating func execute<R: ~Copyable>(
            operation: @autoclosure () -> RecursiveCopyResult.ItemOperation, 
            _ task: () throws -> R
        ) throws(RecursiveCopyAbortError) -> R? {
            do {
                return try task()
            } catch let error as LowLevelError {
                try handleError(error, operation: operation())
                return nil
            } catch let error as RecursiveCopyAbortError {
                throw error
            } catch {
                preconditionFailure(
                    "Unexpected error type \(type(of: error)) thrown from copy operation \(operation()) for item at \(currentItemRelativePath): \(error)"
                )
            }
        }


        mutating func executeAndAbortOnError<R: ~Copyable>(
            operation: @autoclosure () -> RecursiveCopyResult.ItemOperation,
            _ task: () throws -> R
        ) throws(RecursiveCopyAbortError) -> R {
            do {
                return try task()
            } catch let error as LowLevelError {
                try handleErrorAndAbort(error, operation: operation())
            } catch let error as RecursiveCopyAbortError {
                throw error
            } catch {
                preconditionFailure(
                    "Unexpected error type \(type(of: error)) thrown from copy operation \(operation()) for item at \(currentItemRelativePath): \(error)"
                )
            }
        }

    }

}
