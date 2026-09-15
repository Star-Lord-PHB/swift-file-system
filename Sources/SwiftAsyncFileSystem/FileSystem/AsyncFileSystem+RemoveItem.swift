import struct SystemPackage.FilePath
import enum FileSystemCore.InternalFS
import struct FileSystemCore.PlatformError
import class FileSystemCore.CancellationToken
import struct SwiftFileSystem.RecursiveRemoveItemHandler



extension AsyncFileSystem {

    @concurrent
    public func removeItem(at path: FilePath) async throws(PlatformError) {

        do {

            if Task.isCancelled {
                throw PlatformError.taskCancelled(operation: .remove(path))
            }

            let cancellationToken = CancellationToken()

            try await withTaskCancellationHandler {

                var handler = RecursiveRemoveItemHandler(path: path, cancellationToken: cancellationToken)

                while true {

                    let stepResult = await executor.run {

                        let deadline = MonotonicInstant.now() + Self.defaultMultiStepExecTimeSlice

                        var result: RecursiveRemoveItemHandler.StepResult
                        repeat {
                            result = handler.next()
                        } while result == .paused && MonotonicInstant.now() < deadline

                        return result

                    }

                    if stepResult == .completed { 
                        if let firstError = handler.firstError {
                            throw firstError
                        }
                        break 
                    }

                }

            } onCancel: {
                cancellationToken.cancel()
            }

        } catch let error as PlatformError {
            throw error
        } catch {
            preconditionFailure("Unexpected error type: \(error)")
        }

    }

}
