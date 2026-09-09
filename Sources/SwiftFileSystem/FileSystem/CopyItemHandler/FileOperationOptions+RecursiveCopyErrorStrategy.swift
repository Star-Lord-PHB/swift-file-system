import enum FileSystemCore.FileOperationOptions


extension FileOperationOptions {

    public protocol RecursiveCopyErrorStrategyProtocol {
        associatedtype Returned
        associatedtype ThrowedError: Error
        func handleError(_ error: RecursiveCopyResult.SingleItemError) -> (collectError: Bool, abort: Bool)
        func reportResult(_ result: RecursiveCopyResult) throws(ThrowedError) -> Returned
    }


    public struct RecursiveCopyAbortOnErrorStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(_ error: RecursiveCopyResult.SingleItemError) -> (collectError: Bool, abort: Bool) {
            return (collectError: true, abort: true)
        }
        public func reportResult(_ result: RecursiveCopyResult) throws(PlatformError) -> Void {
            if result.operationCancelled {
                assert(result.itemErrors == nil, "Abort on error strategy should not have an error report when cancelled")
                throw .taskCancelled(operation: .recursiveCopy(srcRootPath: result.srcRootPath, dstRootPath: result.dstRootPath))
            }
            guard let errorReport = result.makeItemErrorReport() else { return } 
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
        public func handleError(_ error: RecursiveCopyResult.SingleItemError) -> (collectError: Bool, abort: Bool) {
            return (collectError: true, abort: false)
        }
        public func reportResult(_ result: RecursiveCopyResult) throws(PlatformError) -> Void {
            try result.throwOnErrorOrCancelled()
        }
    }


    public struct RecursiveCopyCollectAndReturnStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(_ error: RecursiveCopyResult.SingleItemError) -> (collectError: Bool, abort: Bool) {
            return (collectError: true, abort: false)
        }
        public func reportResult(_ result: RecursiveCopyResult) throws(Never) -> RecursiveCopyResult {
            return result
        }
    }


    public struct RecursiveCopyIgnoreAllStrategy: RecursiveCopyErrorStrategyProtocol {
        public func handleError(_ error: RecursiveCopyResult.SingleItemError) -> (collectError: Bool, abort: Bool) {
            return (collectError: false, abort: false)
        }
        public func reportResult(_ result: RecursiveCopyResult) throws(PlatformError) -> Void {
            assert(result.itemErrors == nil, "Ignore all strategy should not have an error report")
            try result.throwOnErrorOrCancelled()
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
