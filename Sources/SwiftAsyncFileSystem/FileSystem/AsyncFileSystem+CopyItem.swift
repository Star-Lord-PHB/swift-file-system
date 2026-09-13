import struct SystemPackage.FilePath
import enum SwiftFileSystem.FileOperationOptions
import struct SwiftFileSystem.CopyItemHandler
import class FileSystemCore.CancellationToken



extension AsyncFileSystem {

    @concurrent
    public func copyItem<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>(
        at srcPath: FilePath,
        to dstPath: FilePath,
        options: FileOperationOptions.CopyItemOptions = .init(),
        errorStrategy: ErrorStrategy = .collectAndThrow
    ) async throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.Returned {

        do {

            if Task.isCancelled {
                return try errorStrategy.reportResult(.init(
                    srcRootPath: srcPath, 
                    dstRootPath: dstPath, 
                    itemErrors: nil, 
                    operationCancelled: true
                ))
            }

            let cancellationToken = CancellationToken()

            return try await withTaskCancellationHandler {

                var handler = CopyItemHandler(
                    srcRootPath: srcPath,
                    dstRootPath: dstPath,
                    options: options,
                    cancellationToken: cancellationToken,
                    errorStrategy: errorStrategy
                )

                while true {
                    let stepResult = await executor.run {
                        let deadline = MonotonicInstant.now() + Self.defaultMultiStepExecTimeSlice
                        var result: CopyItemHandler<ErrorStrategy>.StepResult
                        repeat {
                            result = handler.copyStep()
                        } while result == .paused && MonotonicInstant.now() < deadline
                        return result
                    }
                    if stepResult == .completed {
                        return try handler.reportResult()
                    }
                }

            } onCancel: {
                cancellationToken.cancel()
            }

        } catch let error as ErrorStrategy.ThrowedError {
            throw error
        } catch {
            preconditionFailure("Unexpected error type: \(error)")
        }

    }

}
