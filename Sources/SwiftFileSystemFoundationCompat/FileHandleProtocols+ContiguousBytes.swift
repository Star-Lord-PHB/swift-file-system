import protocol Foundation.ContiguousBytes
import protocol SwiftFileSystem.PositionalWriteFileHandleProtocol
import protocol SwiftFileSystem.SequentialWriteFileHandleProtocol
import protocol SwiftFileSystem.MutatingSequentialWriteFileHandleProtocol
import protocol SwiftFileSystem.AppendableFileHandleProtocol
import struct SwiftFileSystem.PlatformError



extension PositionalWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @discardableResult
    public func write(_ data: some ContiguousBytes, toOffset offset: Int64) throws(PlatformError) -> Int64 {
        return try data.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.write(span, toOffset: offset)
        }
    }
    
}



extension SequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @discardableResult
    public func write(_ data: some ContiguousBytes) throws(PlatformError) -> Int64 {
        return try data.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.write(span)
        }
    }

}



extension MutatingSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @discardableResult
    @_lifetime(self: copy self)
    public mutating func write(_ data: some ContiguousBytes) throws(PlatformError) -> Int64 {
        return try data.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.write(span)
        }
    }

}



extension AppendableFileHandleProtocol where Self: ~Copyable & ~Escapable {

    @discardableResult
    public func append(_ data: some ContiguousBytes) throws(PlatformError) -> Int64 {
        return try data.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.append(span)
        }
    }

}
