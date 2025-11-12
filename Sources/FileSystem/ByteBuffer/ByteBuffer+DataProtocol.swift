import Foundation



extension ByteBuffer: ContiguousBytes {

    @inlinable
    public func withUnsafeBytes<R: ~Copyable, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        return try body(.init(storage.buffer))
    }


    @inlinable
    public mutating func withUnsafeMutableBytes<R: ~Copyable, E: Error>(_ body: (UnsafeMutableRawBufferPointer) throws(E) -> R) throws(E) -> R {
        _assessForWrite()
        return try body(.init(storage.buffer))
    }

}



extension ByteBuffer: DataProtocol {

    @inlinable
    public var regions: CollectionOfOne<Self> { .init(self) }

    @inlinable
    public var data: Data { .init(self) }

}