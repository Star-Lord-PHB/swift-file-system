import protocol Foundation.ContiguousBytes
import struct SwiftFileSystem.AppendHandle
import struct SwiftFileSystem.PlatformError
import struct SwiftFileSystem.LowLevelError
import func SwiftFileSystem.catchLowLevelError



extension AppendHandle {

    @discardableResult
    public func append(_ data: some ContiguousBytes) throws(PlatformError) -> Int64 {

        try data.withUnsafeBytesTypedThrow { buffer throws(PlatformError) in
            try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
                try withUnsafeSystemHandle { handle throws(LowLevelError) in
                    try handle.write(contentsOf: buffer)
                }
            }
        }

    }

}
