import enum FileSystemCore.FileOperationOptions


extension FileOperationOptions {

    public protocol RecursiveCopyErrorStrategyProtocol {
        associatedtype ReturnedError
        associatedtype ThrowedError: Error
        func handleError(lowLevelError: LowLevelError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool)
        func reportError(_ errorReport: RecursiveCopyErrorReport?) throws(ThrowedError) -> ReturnedError
    }


    public struct RecursiveCopyAbortOnErrorStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(lowLevelError: LowLevelError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool) {
            return (collectError: true, abort: true)
        }
        public func reportError(_ errorReport: RecursiveCopyErrorReport?) throws(PlatformError) -> Void {
            guard let errorReport else { return } 
            assert(errorReport.errors.count == 1, "Abort on error strategy should only have one error in the report")
            let error = errorReport.errors.first
            throw .init(
                systemCode: error.systemCode, 
                kind: error.kind,
                operation: .copy(
                    srcPath: errorReport.srcRootPath.appending(error.itemRelativePath.components), 
                    dstPath: errorReport.dstRootPath.appending(error.itemRelativePath.components)
                )
            )!
        }
    }


    public struct RecursiveCopyCollectAndThrowStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(lowLevelError: LowLevelError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool) {
            return (collectError: true, abort: false)
        }
        public func reportError(_ errorReport: RecursiveCopyErrorReport?) throws(PlatformError) -> Void {
            guard let errorReport else { return }
            try errorReport.throwAsPlatformError()
        }
    }


    public struct RecursiveCopyCollectAndReturnStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(lowLevelError: LowLevelError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool) {
            return (collectError: true, abort: false)
        }
        public func reportError(_ errorReport: RecursiveCopyErrorReport?) throws(Never) -> RecursiveCopyErrorReport? {
            return errorReport
        }
    }


    public struct RecursiveCopyIgnoreAllStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(lowLevelError: LowLevelError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool) {
            return (collectError: false, abort: false)
        }
        public func reportError(_ errorReport: RecursiveCopyErrorReport?) throws(Never) -> Void {
            // do nothing (ignore all errors)
        }
    }

}



extension FileOperationOptions.RecursiveCopyErrorStrategyProtocol where Self == FileOperationOptions.RecursiveCopyAbortOnErrorStrategy {
    public static var abortOnError: FileOperationOptions.RecursiveCopyAbortOnErrorStrategy { .init() }
}


extension FileOperationOptions.RecursiveCopyErrorStrategyProtocol where Self == FileOperationOptions.RecursiveCopyCollectAndThrowStrategy {
    public static var collectAndThrow: FileOperationOptions.RecursiveCopyCollectAndThrowStrategy { .init() }
}


extension FileOperationOptions.RecursiveCopyErrorStrategyProtocol where Self == FileOperationOptions.RecursiveCopyCollectAndReturnStrategy {
    public static var collectAndReturn: FileOperationOptions.RecursiveCopyCollectAndReturnStrategy { .init() }
}


extension FileOperationOptions.RecursiveCopyErrorStrategyProtocol where Self == FileOperationOptions.RecursiveCopyIgnoreAllStrategy {
    public static var ignoreAll: FileOperationOptions.RecursiveCopyIgnoreAllStrategy { .init() }
}