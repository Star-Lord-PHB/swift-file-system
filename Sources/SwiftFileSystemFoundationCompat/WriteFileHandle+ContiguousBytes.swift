import protocol Foundation.ContiguousBytes
import struct SwiftFileSystem.WriteFileHandle
import struct SwiftFileSystem.ReadWriteFileHandle
import struct SwiftFileSystem.PlatformError



extension WriteFileHandle {
    
    public func write(_ data: some ContiguousBytes, toOffset offset: Int64? = nil) throws(PlatformError) -> Int64 {
        return try data.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.write(span, toOffset: offset)
        }
    }
    
}



extension ReadWriteFileHandle {
    
    public func write(_ data: some ContiguousBytes, toOffset offset: Int64? = nil) throws(PlatformError) -> Int64 {
        return try data.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.write(span, toOffset: offset)
        }
    }
    
}
