import protocol Foundation.ContiguousBytes
import struct SwiftFileSystem.AppendHandle
import struct SwiftFileSystem.PlatformError
import struct SwiftFileSystem.SystemError
import func SwiftFileSystem.catchSystemError



extension AppendHandle {

    @discardableResult
    public func append(_ data: some ContiguousBytes) throws(PlatformError) -> Int64 {

        try data.withUnsafeBytesTypedThrow { buffer throws(PlatformError) in
            try catchSystemError(operation: .writeHandle(originalPath: path)) { () throws(SystemError) in
                try withUnsafeSystemHandle { handle throws(SystemError) in
                    try handle.write(contentsOf: buffer)
                }
            }
        }

    }

}
