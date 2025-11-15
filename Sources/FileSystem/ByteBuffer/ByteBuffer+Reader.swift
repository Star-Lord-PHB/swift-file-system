import Foundation


extension ByteBuffer {

    public struct Reader: ~Escapable {

        @usableFromInline var storage: Storage
        public let count: Int

        @usableFromInline var _readOffset: Int = 0

        @inlinable
        public var readOffset: Int { return _readOffset }

        @inlinable
        public var remainingBytes: Int { return count - readOffset }


        @_lifetime(immortal)
        @inlinable
        init(storage: Storage, count: Int, startOffset: Int) {
            self.storage = storage
            self.count = count
            self._readOffset = startOffset
        }


        @_lifetime(borrow byteBuffer)
        @inlinable
        public init(_ byteBuffer: borrowing ByteBuffer) {
            self.storage = byteBuffer.storage
            self.count = byteBuffer.count
            self._readOffset = byteBuffer.startOffsetInStorage
        }


        @inlinable
        public mutating func readByte() -> Byte? {
            guard readOffset < count else {
                return nil
            }
            defer { _readOffset += 1 }
            return storage[_readOffset]
        }


        @_lifetime(self: copy self)
        @inlinable
        public mutating func readBytes(upTo length: Int) -> ByteBuffer {
            
            guard length > 0, remainingBytes > 0 else { return .init() }

            let lengthToRead = Swift.min(remainingBytes, length)
            defer { _readOffset += lengthToRead }

            return ByteBuffer(storage.buffer[readOffset ..< readOffset + lengthToRead])

        }


        @_lifetime(self: copy self)
        @inlinable
        public mutating func read<T>(as type: T.Type) -> T? {

            let size = MemoryLayout<T>.size

            guard remainingBytes >= size else { return nil }
            defer { _readOffset += size }
            
            return storage.buffer.baseAddress?.loadUnaligned(fromByteOffset: readOffset, as: T.self)

        }

    }


    @_lifetime(borrow self)
    @inlinable
    public func reader() -> Reader {
        return Reader(self)
    }

}



extension ByteBuffer.Reader {

    @_lifetime(self: copy self)
    @inlinable
    public mutating func skip(_ length: Int) {
        _readOffset += Swift.min(remainingBytes, length)
    }

    @inlinable
    public mutating func readInt() -> Int? {
        return self.read(as: Int.self)
    }

    @inlinable
    public mutating func readUInt() -> UInt? {
        return self.read(as: UInt.self)
    }

    @inlinable
    public mutating func readInt8() -> Int8? {
        return self.read(as: Int8.self)
    }

    @inlinable
    public mutating func readUInt8() -> UInt8? {
        return self.read(as: UInt8.self)
    }

    @inlinable
    public mutating func readInt16() -> Int16? {
        return self.read(as: Int16.self)
    }

    @inlinable
    public mutating func readUInt16() -> UInt16? {
        return self.read(as: UInt16.self)
    }

    @inlinable
    public mutating func readInt32() -> Int32? {
        return self.read(as: Int32.self)
    }

    @inlinable
    public mutating func readUInt32() -> UInt32? {
        return self.read(as: UInt32.self)
    }

    @inlinable
    public mutating func readInt64() -> Int64? {
        return self.read(as: Int64.self)
    }

    @inlinable
    public mutating func readUInt64() -> UInt64? {
        return self.read(as: UInt64.self)
    }

    @inlinable
    public mutating func readFloat() -> Float? {
        return self.read(as: Float.self)
    }

    @inlinable
    public mutating func readDouble() -> Double? {
        return self.read(as: Double.self)
    }

    @inlinable
    public mutating func readFloat16() -> Float16? {
        return self.read(as: Float16.self)
    }

    @inlinable
    public mutating func readBool() -> Bool? {
        return self.read(as: Bool.self)
    }

    @_lifetime(self: copy self)
    @inlinable
    public mutating func readString(upTo byteCount: Int, encoding: String.Encoding = .utf8) -> String? {

        guard byteCount > 0, remainingBytes >= 0 else { return nil }

        let byteCountToRead = Swift.min(remainingBytes, byteCount)
        defer { _readOffset += byteCountToRead }

        return String(bytes: storage.buffer[readOffset ..< readOffset + byteCountToRead], encoding: encoding)

    }

}