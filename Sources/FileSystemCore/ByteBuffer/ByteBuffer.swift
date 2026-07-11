import PlatformCLib



public struct ByteBuffer {

    @usableFromInline var storage: Storage

    @_alwaysEmitIntoClient public internal(set) var count: Int
    @usableFromInline var startOffsetInStorage: Int

    @inlinable var endOffsetInStorage: Int { startOffsetInStorage + count }
    @inlinable var rangeInStorage: Range<Int> { startOffsetInStorage ..< endOffsetInStorage }
    @inlinable public var capacity: Int { storage.capacity - startOffsetInStorage }

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
    mutating func isNotUnique() -> Bool {
        return !isKnownUniquelyReferenced(&storage)
    }


    @inlinable 
    mutating func _accessForNoAppendWrite() {
        guard isNotUnique() else { return }
        let newStorage = Storage(capacityForAtLeast: count, zeroed: false)
        newStorage.copyBytes(from: self.storage[rangeInStorage])
        self.storage = newStorage
        self.startOffsetInStorage = 0
    }


    @inlinable
    mutating func _ensureEnoughLogicalCapacityAndRebaseIfNeeded(for byteCount: Int, ensureUnique: Bool = true) {

        if byteCount > storage.capacity {

            let newBuffer = Storage.allocateBuffer(forAtLeast: byteCount)

            newBuffer.copyBytes(from: storage[rangeInStorage])

            if isNotUnique() {
                self.storage = Storage(capacity: 0, zeroed: false)
            }
            self.storage.swapBuffer(newBuffer)
            self.startOffsetInStorage = 0

        } else if byteCount > capacity {

            if isNotUnique() {
                let newStorage = Storage(capacityForAtLeast: byteCount, zeroed: false)
                newStorage.copyBytes(from: storage[rangeInStorage])
                self.storage = newStorage
            } else {
                storage.copyBytes(from: storage[rangeInStorage])
            }
            self.startOffsetInStorage = 0

        } else if ensureUnique && isNotUnique() {

            let newStorage = Storage(capacity: capacity, zeroed: false)
            newStorage.copyBytes(from: storage[rangeInStorage])
            self.storage = newStorage
            self.startOffsetInStorage = 0

        }

    }


    @inlinable
    mutating func _resizeStorageAndRebaseIfNeeded(toExactly newCapacity: Int, ensureUnique: Bool = true) {

        if newCapacity != storage.capacity {

            let newBuffer = newCapacity == 0 
                ? UnsafeMutableRawBufferPointer(start: nil, count: 0) 
                : Storage.allocateBuffer(byteCount: newCapacity)

            let copyRange = startOffsetInStorage ..< startOffsetInStorage + Swift.min(newCapacity, count)
            newBuffer.copyBytes(from: storage[copyRange])

            if isNotUnique() {
                self.storage = Storage(capacity: 0, zeroed: false)
            }
            self.storage.swapBuffer(newBuffer)

            self.startOffsetInStorage = 0

        } else if startOffsetInStorage != 0 {

            if isNotUnique() {
                let newStorage = Storage(capacity: storage.capacity, zeroed: false)
                newStorage.copyBytes(from: storage[rangeInStorage])
                self.storage = newStorage
            } else {
                storage.copyBytes(from: storage[rangeInStorage])
            }

            self.startOffsetInStorage = 0

        } else if ensureUnique && isNotUnique() {

            let newStorage = Storage(capacity: storage.capacity, zeroed: false)
            newStorage.copyBytes(from: storage[rangeInStorage])
            self.storage = newStorage
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
    func _writeBytes<Bytes: Collection>(_ bytes: Bytes, to logicalOffset: Int) where Bytes.Element == Element {

        let offsetInStorage = indexInStorage(for: logicalOffset)
        
        let hasContiguousStorage = bytes.withContiguousStorageIfAvailable { buffer in
            storage[offsetInStorage...].copyBytes(from: buffer)
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
        // only evaluate the writePtr when the bytes are not empty
        lazy var writePtr = storage.pointer(to: offsetInStorage)
        
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
        guard count < storage.capacity else { return }
        _resizeStorageAndRebaseIfNeeded(toExactly: count, ensureUnique: false)
    }
    
    
    @inlinable
    public mutating func reserveCapacity(_ capacity: Int) {
        guard capacity > self.capacity else { return }
        let targetCapacity = Swift.max(capacity, Storage.recommendedCapacity(forAtLeast: count))
        _resizeStorageAndRebaseIfNeeded(toExactly: targetCapacity)
    }
    
}

