import protocol Foundation.ContiguousBytes
import struct SwiftFileSystem.AppendHandle
import struct SwiftFileSystem.PlatformError



extension AppendHandle {

    @discardableResult
    public func append(_ data: some ContiguousBytes) throws(PlatformError) -> Int64 {
        return try data.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.append(span)
        }
    }

}
