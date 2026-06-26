import PlatformCLib



public struct ByteBuffer {

    @usableFromInline var storage: Storage

    @_alwaysEmitIntoClient public internal(set) var count: Int
    @usableFromInline var startOffsetInStorage: Int

    @inlinable var endOffsetInStorage: Int { startOffsetInStorage + count }
    @inlinable var rangeInStorage: Range<Int> { startOffsetInStorage ..< endOffsetInStorage }
    @inlinable public var capacity: Int { storage.capacity }

    @inlinable 
    public init() {
        self.storage = Storage(capacity: 0)
        self.count = 0
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init(repeating value: Byte, count: Int) {
        precondition(count >= 0, "count must be non-negative")
        self.storage = Storage(repeating: value, count: count)
        self.count = count
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init(count: Int) {
        precondition(count >= 0, "count must be non-negative")
        self.storage = Storage(capacity: count, zeroed: true)
        self.count = count
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init(capacity: Int) {
        precondition(capacity >= 0, "capacity must be non-negative")
        self.storage = Storage(capacity: capacity)
        self.count = 0
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init(_ byteBuffer: ByteBuffer) {
        if byteBuffer.isEmpty {
            self.storage = Storage(capacity: 0)
            self.count = 0
            self.startOffsetInStorage = 0
        } else {
            self.storage = byteBuffer.storage
            self.count = byteBuffer.count
            self.startOffsetInStorage = byteBuffer.startOffsetInStorage
        }
    }


    @inlinable
    public init(_ byteBufferSlice: Slice<ByteBuffer>) {
        if byteBufferSlice.isEmpty {
            self.storage = Storage(capacity: 0)
            self.count = 0
            self.startOffsetInStorage = 0
        } else {
            self.storage = byteBufferSlice.base.storage
            self.count = byteBufferSlice.count
            self.startOffsetInStorage = byteBufferSlice.base.startOffsetInStorage + byteBufferSlice.startIndex
        }
    }


    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Byte {
        self.storage = Storage(capacity: 0)
        self.count = 0
        self.startOffsetInStorage = 0
        self.append(contentsOf: elements)
    }

}



extension ByteBuffer: @unchecked Sendable { }



extension ByteBuffer: CustomStringConvertible {

    @inlinable
    public var description: String {
        "ByteBuffer(count: \(count) bytes)"
    }

}



extension ByteBuffer: ExpressibleByArrayLiteral {

    @inlinable
    public init(arrayLiteral elements: Byte...) {
        self.init(elements)
    }

}



extension ByteBuffer: Equatable, Hashable {

    @inlinable
    public static func == (lhs: ByteBuffer, rhs: ByteBuffer) -> Bool {
        if lhs.storage.baseAddress == rhs.storage.baseAddress && lhs.startOffsetInStorage == rhs.startOffsetInStorage && lhs.count == rhs.count {
            return true
        }
        guard lhs.count == rhs.count else { return false }
        guard 
            let lhsPtr = lhs.storage.baseAddress?.advanced(by: lhs.startOffsetInStorage), 
            let rhsPtr = rhs.storage.baseAddress?.advanced(by: rhs.startOffsetInStorage) 
        else { return false }
        return memcmp(lhsPtr, rhsPtr, lhs.count) == 0
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        // TODO: Consider a way of hashing for large buffers? 
        hasher.combine(bytes: .init(rebasing: storage.buffer[rangeInStorage]))
    }

}



extension ByteBuffer {

    @inlinable
    mutating func _assessForWrite() {
        if !isKnownUniquelyReferenced(&storage) {
            self.storage = storage.copy(range: rangeInStorage)
            self.startOffsetInStorage = 0
        }
    }


    @inlinable
    func indexInStorage(for index: Int) -> Int {
        return startOffsetInStorage + index
    }


    @inlinable
    func rangeInStorage(for range: Range<Int>) -> Range<Int> {
        return (startOffsetInStorage + range.lowerBound) ..< (startOffsetInStorage + range.upperBound)
    }


    @inlinable
    func preconditionValidIndex(_ index: Int, file: StaticString = #file, line: UInt = #line) {
        precondition(index >= 0 && index < count, "Index out of bounds", file: file, line: line)
    }


    @inlinable
    func preconditionValidRange(_ range: Range<Int>, file: StaticString = #file, line: UInt = #line) {
        precondition(range.lowerBound >= 0 && range.upperBound <= count, "Range out of bounds", file: file, line: line)
    }
    
    
    @inlinable
    func _writeBytes<Bytes: Collection>(_ bytes: Bytes, to offset: Int) where Bytes.Element == Element {
        
        let hasContiguousStorage = bytes.withContiguousStorageIfAvailable { buffer in
            storage.copyBytes(from: .init(buffer), toOffset: offset)
            return true
        } ?? false
        
        guard _slowPath(!hasContiguousStorage) else { return }
        
        var inlineBuffer = InlineBuffer(
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
        var inlineBufferWrittenCount = 0
        var writePtr = storage.pointer(to: offset)
        
        for byte in bytes {
            
            if inlineBufferWrittenCount == MemoryLayout<InlineBuffer>.size {
                assert(
                    writePtr + inlineBufferWrittenCount <= storage.baseAddress! + count,
                    "writing beyond the end of the buffer"
                )
                Swift.withUnsafeBytes(of: &inlineBuffer) { buffer in
                    writePtr.copyMemory(from: buffer.baseAddress!, byteCount: inlineBufferWrittenCount)
                }
                writePtr += inlineBufferWrittenCount
                inlineBufferWrittenCount = 0
            }
            
            Swift.withUnsafeMutableBytes(of: &inlineBuffer) { buffer in
                buffer[inlineBufferWrittenCount] = byte
            }
            inlineBufferWrittenCount += 1
            
        }
        
        if inlineBufferWrittenCount > 0 {
            Swift.withUnsafeBytes(of: &inlineBuffer) { buffer in
                assert(
                    writePtr + inlineBufferWrittenCount <= storage.baseAddress! + count,
                    "writing beyond subrange"
                )
                writePtr.copyMemory(from: buffer.baseAddress!, byteCount: inlineBufferWrittenCount)
            }
        }
        
    }

}



extension ByteBuffer {
    
    @inlinable
    public mutating func shrinkToFit() {
        _assessForWrite()
        storage.resize(forAtLeast: endOffsetInStorage)
    }
    
    
    @inlinable
    public mutating func reserveCapacity(_ capacity: Int) {
        _assessForWrite()
        storage.allocateEnoughCapacityIfNeeded(for: startOffsetInStorage + capacity)
    }
    
}

