import enum FileSystemCore.FileOperationOptions


extension FileOperationOptions {

    public protocol RecursiveCopyErrorStrategyProtocol {
        associatedtype ReturnedError
        associatedtype ThrowedError: Error
        func handleError(_ error: SystemError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool)
        func reportError(_ errorReport: RecursiveCopyErrorReport?) throws(ThrowedError) -> ReturnedError
    }


    public struct RecursiveCopyAbortOnErrorStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(_ error: SystemError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool) {
            return (collectError: true, abort: true)
        }
        public func reportError(_ errorReport: RecursiveCopyErrorReport?) throws(PlatformError) -> Void {
            guard let errorReport else { return } 
            let error = errorReport.errors.first
            throw .init(
                code: error.code, 
                operation: .copy(
                    srcPath: errorReport.srcRootPath.appending(error.itemRelativePath.components), 
                    dstPath: errorReport.dstRootPath.appending(error.itemRelativePath.components)
                )
            )!
        }
    }


    public struct RecursiveCopySkipAndCollectStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(_ error: SystemError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool) {
            return (collectError: true, abort: false)
        }
        public func reportError(_ errorReport: RecursiveCopyErrorReport?) throws(Never) -> RecursiveCopyErrorReport? {
            return errorReport
        }
    }


    public struct RecursiveCopySkipAndIgnoreStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(_ error: SystemError, itemRelativePath: FilePath) -> (collectError: Bool, abort: Bool) {
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


extension FileOperationOptions.RecursiveCopyErrorStrategyProtocol where Self == FileOperationOptions.RecursiveCopySkipAndCollectStrategy {
    public static var skipAndCollect: FileOperationOptions.RecursiveCopySkipAndCollectStrategy { .init() }
}


extension FileOperationOptions.RecursiveCopyErrorStrategyProtocol where Self == FileOperationOptions.RecursiveCopySkipAndIgnoreStrategy {
    public static var skipAndIgnore: FileOperationOptions.RecursiveCopySkipAndIgnoreStrategy { .init() }
}