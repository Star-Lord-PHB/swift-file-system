import Foundation



extension ByteBuffer: ContiguousBytes {

    @inlinable
    public func withUnsafeBytes<R: ~Copyable, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        return try body(.init(rebasing: storage.buffer[rangeInStorage]))
    }


    @inlinable
    public mutating func withUnsafeMutableBytes<R: ~Copyable, E: Error>(_ body: (UnsafeMutableRawBufferPointer) throws(E) -> R) throws(E) -> R {
        _assessForWrite()
        return try body(.init(rebasing: storage.buffer[rangeInStorage]))
    }

}



extension ByteBuffer: DataProtocol {

    @inlinable
    public var regions: CollectionOfOne<Self> { .init(self) }

    @inlinable
    public var data: Data { .init(self) }

}



extension ByteBuffer {

    @inlinable
    public mutating func store<Bytes: ContiguousBytes>(bytes: Bytes, toOffset offset: Int) {
        bytes.withUnsafeBytes { buffer in
            self.store(buffer, toOffset: offset)
        }
    }


    @inlinable
    public mutating func append<Bytes: ContiguousBytes>(bytes: Bytes) {
        bytes.withUnsafeBytes { buffer in
            self.append(contentsOf: buffer)
        }
    }

}