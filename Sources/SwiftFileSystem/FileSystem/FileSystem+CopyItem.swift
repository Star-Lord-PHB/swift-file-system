import struct SystemPackage.FilePath
import FileSystemCore


extension FileSystem {

    public func copyItem<ErrorStrategy: FileOperationOptions.RecursiveCopyErrorStrategyProtocol>(
        at srcPath: FilePath,
        to dstPath: FilePath,
        options: FileOperationOptions.CopyItemOptions = .init(),
        errorStrategy: ErrorStrategy = .abortOnError
    ) throws(ErrorStrategy.ThrowedError) -> ErrorStrategy.ReturnedError {
        return try CopyItemHandler.copyItem(at: srcPath, to: dstPath, options: options, errorStrategy: errorStrategy)
    }

}
