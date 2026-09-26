import protocol Foundation.ContiguousBytes
import SwiftFileSystem



extension PositionalWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Writes the provided bytes into the file handle at the specified offset.
    /// - Parameters:
    ///   - bytes: The bytes to write into the file handle.
    ///   - offset: The offset relative to the beginning of the file to write to.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    public func write(_ bytes: some ContiguousBytes, toOffset offset: Int64) throws(PlatformError) -> Int64 {
        return try bytes.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.write(span, toOffset: offset)
        }
    }
    
}



extension SequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Writes the provided bytes into the file handle at the current position of the file pointer.
    /// - Parameter bytes: The bytes to write into the file handle.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    public func write(_ bytes: some ContiguousBytes) throws(PlatformError) -> Int64 {
        return try bytes.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.write(span)
        }
    }

}



extension MutatingSequentialWriteFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Writes the provided bytes into the file handle at the current position of the file pointer.
    /// - Parameter bytes: The bytes to write into the file handle.
    /// - Returns: The number of bytes actually written into the file handle.
    @discardableResult
    @_lifetime(self: copy self)
    public mutating func write(_ bytes: some ContiguousBytes) throws(PlatformError) -> Int64 {
        return try bytes.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.write(span)
        }
    }

}



extension AppendableFileHandleProtocol where Self: ~Copyable & ~Escapable {

    /// Appends the provided bytes to the end of the file handle atomically.
    /// - Parameter bytes: The bytes to append to the end of the file handle.
    /// - Returns: The number of bytes actually appended to the file handle.
    @discardableResult
    public func append(_ bytes: some ContiguousBytes) throws(PlatformError) -> Int64 {
        return try bytes.withUnsafeBytesTypedThrow { ptr throws(PlatformError) in
            let span = RawSpan(_unsafeBytes: ptr)
            return try self.append(span)
        }
    }

}
